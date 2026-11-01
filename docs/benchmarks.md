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
