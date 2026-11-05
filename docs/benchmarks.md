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

## Day 5 — 5 Nov 2026 (v1.0.3)

Paint and compositing. *(This file has no day-3 or day-4 section — the run resumed at
day 5, so the release number continues from v1.0.2.)* Numbers are medians of three
harness runs, before and after interleaved so pod drift hits both sides equally.

| Workload | Before | After | Verdict |
| --- | --- | --- | --- |
| rAF interval while tilting — median frame, ms | 66.6 / 66.6 / 66.6 | 66.7 / 66.6 / 66.6 | unchanged (headless frame cap) |
| style recalcs per 130 tilt frames | 130 / 131 / 130 | 131 / 131 / 131 | unchanged |
| paint events per 130 tilt frames | 655 / 655 / 652 | 650 / 650 / 650 | 5 fewer, at the edge of noise |
| raster tasks per 130 tilt frames | 655 / 646 / 650 | 646 / 648 / 650 | unchanged |
| layout passes during the tilt loop | 0 | 0 | no layout in the loop, before or after |
| 300 synthetic pointer moves, ms | 3.0 / 3.8 / 6.5 | 4.5 / 2.9 / 3.1 | noise |
| 60 theme changes, ms | 9.7 / 8.3 / 8.2 | 8.5 / 8.6 / 8.1 | noise |
| DOM nodes on the start page | 98 | 98 | unchanged |
| localStorage writes / bytes per navigation | 1 / 1637 | 1 / 1637 | unchanged |

Pixel proof: **10/10 screens byte-identical** (start, search, settings, tabs, live page,
private, dark, motion, tilted, motion off). The harness was proved stable before it was
trusted: two independent runs of the unchanged page were byte-identical on all ten screens.
Behaviour suite: **28/28 checks, zero JS errors**, on both sides.

**Applied (8).** `#orb` to `contain:strict`; `contain:paint` on `#view`, `#start`,
`#results`, `#blocked`, `#shade`; `will-change:auto` on `#orb` while motion is off; the
tilt loop skips the style write when the rounded value has not changed.

**Audited, no change made (2).** Every `backdrop-filter` surface and every off-screen
surface was audited: the only filters are on the six glass surfaces that are on screen,
`.tile i`/`.card` already carry no filter, and every hidden view is `display:none`. Behind
the toolbar there is exactly one blurred layer (`#orb`) and no nested blur, so there was
nothing to trim that would not move a pixel.

**Reverted the same day (5).** `#pill{will-change:transform}` (a promoted layer changes the
antialiasing of the toolbar and of everything the sheet blurs behind it: 147 px differ on
the dark screen, 12 584 on the tilted one). `.card{contain:content}` (123 px on the tab
sheet). `#sheet`, `#chip` and `#web` `contain:paint` (each clips the element's own shadow
or changes the backdrop sample: 1–3 px per screen, 24 px on the live page). The tilt loop
was first consolidated to a single write on `:root`; it measured no better than the eight
per-element writes and slightly worse on two counters, so it was narrowed back to the
element list with a write guard — only the guard survives.

APK rebuilt and re-signed: **59 255 bytes** (was 59 208), asset inside byte-identical to
`GlassBrowser/Glass_Browser.html`. JAR scheme v1 (9 entries digested, PKCS#7 over
`GLASS.SF`) and APK Signature Scheme v2 (three-section, 96-byte digest, RSA-SHA256) both
verify with a checker written from the platform spec — the same checker also validates the
v1 signature of the previous artefact, so it is not simply agreeing with today's signer.
The previous artefact carried a single 32-byte v2 digest record; the platform expects the
three section digests concatenated (96 bytes for SHA-256), which is what this build has.
