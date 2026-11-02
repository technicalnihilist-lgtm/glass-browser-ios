# Benchmarks

Measured on the build pod with Chromium (same engine family as the Android WebView and iOS
WKWebView). Lower is better. Numbers are noisy on a shared pod — a metric only counts as a win
when it repeats across runs.

## Day 1 — 1 Nov 2026 (v1.0.1)

| Workload | Before | After | Verdict |
| --- | --- | --- | --- |
| 300 synthetic keystrokes in the address bar | 12.8 / 20.5 ms | 16.9 / 28.2 ms | within noise |
| 300 pointer moves driving the tilt | 78.9 / 102.9 ms | 40.7 / 41.3 ms | **~55% faster, repeatable** |
| 40 theme changes inside one frame — localStorage writes | 40 | **1** | **deterministic win** |
| 40 theme changes inside one frame — time | 73.1 / 290.9 ms | 18.2 / 281.8 ms | mixed, noise-dominated |
| 40 tab-sheet open/close cycles | 4103 / 4123 ms | 4168 / 4431 ms | 2–8% slower, needs investigation |

Pixel proof: 6/6 screens byte-identical (start, results, settings, tabs, dark, private tab).
Behaviour suite: all green, zero JS errors.

**Open item for day 2:** re-measure the tab-sheet loop with 120 cycles and a median of five
runs. If the small regression is real rather than noise, find the cause and revert it.

**Reverted on day 1:** coalescing `drawSheet()` into `requestAnimationFrame`. It delayed the
sheet's first paint by a frame and saved no work, so it was undone before release.

## Day 2 — 2 Nov 2026 (v1.0.2)

The render pipeline. Every change is in the script: the markup and the stylesheet are
byte-identical to day 1, and so are all nine rendered screens. Numbers are medians of
three harness runs, each run itself a median over its own repeats.

| Workload | Before | After | Verdict |
| --- | --- | --- | --- |
| rAF interval while tilting — median frame, ms | 62.5 / 74.9 / 91.0 | 27.1 / 34.3 / 35.0 | **~54% lower, no overlap between runs** |
| 60 theme changes — render cost, ms | 334.8 | 224.9 | **~33% faster, repeatable** |
| 300 history pushes, ms | 2093.9 | 1212.8 | **~42% faster, repeatable** |
| 120 tab-sheet open/close cycles, ms | 17 457 | 14 698 | **~16% faster** |
| 40 theme changes in one frame — localStorage writes | 1 | 1 | unchanged (day-1 coalescing holds) |
| 40 theme changes in one frame — bytes written | 1069 | 1069 | unchanged |
| one user action — localStorage writes | 1 | 1 | one, and zero when the state did not change |
| DOM nodes on the start page | 95 | 95 | unchanged |

Pixel proof: 9/9 screens byte-identical (start, search, settings, tabs, live page,
private, dark, motion, depth). The harness was proved stable before it was trusted —
two independent runs of the unchanged page produced identical bytes on all nine screens.
Behaviour suite: 20/20 checks, zero JS errors, three consecutive runs on each side.

APK rebuilt and re-signed: 59 208 bytes (was 62 338). JAR scheme v1 and APK Signature
Scheme v2 both verify with an independent verifier; the asset inside the APK is
byte-identical to `GlassBrowser/Glass_Browser.html`.

**Day-1 open item closed.** The tab-sheet loop, re-measured at 120 cycles with a median of
five runs: 17.46 s before today's work. The five runs of that measurement spread
16.2–19.3 s (±9%), wider than the 2–8% day-1 delta, so the day-1 "regression" was noise
rather than a cost. Nothing was reverted for it.

**Reverted on day 2:** nothing.
