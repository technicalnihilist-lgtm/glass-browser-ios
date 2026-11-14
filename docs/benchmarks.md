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

## Day 7 — 7 Nov 2026 (v1.0.4)

The motion loop. *(This file has no day-6 section — the run resumed at day 7, so the
release number continues from v1.0.3.)* Numbers are medians of five harness runs. The
harness was proved stable and sensitive before it was trusted: two runs of the unchanged
page were byte-identical on all ten screens, and a one-pixel change to `--r` was caught on
nine of the ten.

| Workload | Before | After | Verdict |
| --- | --- | --- | --- |
| rAF interval, idle — median frame, ms | 16.7 | 16.7 | unchanged (headless frame cap) |
| 120-move tilt sweep — frames requested | 123 | 116 | noise (±8% between runs of one file) |
| 120-move tilt sweep — style writes | 1136 | 1088 | noise; per frame 9.24 vs 9.38 |
| 120-move tilt sweep — wall clock, ms | 3940.5 | 3905.1 | noise |
| 60 theme changes, ms | 3821.5 | 3823.7 | unchanged |
| 60-step toolbar drag — layout reads (`getBoundingClientRect`) | 32 | **9** | **72% fewer, deterministic** |
| 30 pointer moves while the page is hidden — frames requested | 5 | **0** | **deterministic win** |
| 600 `deviceorientation` events in one task, ms | 4.3 | **2.8** | **~35% faster, repeatable** |
| DOM nodes on the start page | 67 | 67 | unchanged |
| localStorage writes / bytes per navigation | 1 / 480 | 1 / 480 | unchanged |

Pixel proof: **10/10 screens byte-identical** (start, search, settings, tabs, live page,
private, dark, motion, tilted, motion off). Behaviour suite: **21/21 checks, zero JS
errors**, on both sides.

**The motion proof.** The tilt loop was driven from a manual clock so the trajectory can be
compared frame by frame, with every stray pointer event swallowed. At 60 Hz, 120 Hz and
30 Hz the written `--tx`/`--ty` series are **identical, to the third decimal, before and
after**. The delta-time step only fires on a genuine stall: in a series of five 60 Hz frames
followed by a 100 ms gap (six dropped frames) the old loop lost five frames of motion and
the new one advances three sub-steps in that frame and rejoins the same curve — the only
series that differs, by design.

**Applied (10).** A fixed-step delta-time accumulator in the tilt loop, engaging only when a
frame took more than 2.5 frame times, capped at three sub-steps; the accumulator's clock is
cleared on every external kick, so an idle gap can never fling the transform; spring
position and velocity clamped to bounds above the measured peak (see below); `kick()`
returns without scheduling when animations or tilt are off, so no frame is requested at
all; the loop is cancelled on `visibilitychange` → hidden and its clock reset, so nothing
runs in the background and nothing bursts on resume; the write guard now compares rounded
integers and builds the two strings only on an actual write; `aim()` returns early when the
clamped target equals the value already held; `deviceorientation` bursts are coalesced to
one tilt update per frame, matching the pointer path; the toolbar's rects are cached for the
duration of a pill drag instead of two `getBoundingClientRect()` calls per pointermove; the
pointer and sensor handlers early-return while the page is hidden.

**Reworked the same day (2), before release.** The delta-time first advanced a sub-step on
any frame slower than 60 Hz. That changed where the spring comes to rest — up to 0.08 in
`--ty`, which moved the toolbar by about a pixel and put 1 414 pixels of difference on the
live screen — so it was narrowed to genuine stalls (frames over 2.5 frame times), after
which the pixel diff returned to zero. The clamp was first set to ±1.2, which clipped the
transform on the search screen (7 425 px): the spring's real peak, measured over a 200-event
sweep, is 1.21, so the bound is ±2.0 and ±1.5 for velocity, and the guard never engages in
normal motion.

**Harness note.** Headless Chromium picks one of two glyph-antialiasing modes per page load,
so two runs of the *same* file are not always byte-identical (up to 240/255 on text edges).
The pixel harness therefore renders the old and the new file in two iframes of the same
top-level document, one after the other, so both see the same renderer state; the comparison
is exact and repeatable.

APK rebuilt and re-signed: **59 666 bytes** (was 59 255), the asset inside byte-identical to
`GlassBrowser/Glass_Browser.html` (SHA-256 `9ca0f245ff6f15cd…`). JAR scheme v1 (9 entries
digested, PKCS#7 over `GLASS.SF`) and APK Signature Scheme v2 (one chunk, 32-byte digest,
RSA-SHA256) both verify with the checker written from the platform spec; that same checker
rejects the previous artefact's v2 block, which carried a single bare digest record, so it
is not simply agreeing with today's signer. The repo carries no key material, so this build
was signed with a freshly generated self-signed key, as on the earlier days.

## Day 8 — 8 Nov 2026 (v1.0.5)

The tab lifecycle. Numbers are medians of three harness runs, before and after interleaved so
pod drift hits both sides equally. The harness was proved stable and sensitive before it was
trusted: two runs of the unchanged page were byte-identical on all ten screens, and a
one-pixel change (the toolbar moved 1 px) was caught on all ten, on all four attempts.

| Workload | Before | After | Verdict |
| --- | --- | --- | --- |
| 20 card closes from an open tab sheet, 200 tabs — main-thread task time, ms | 3248 | **1267** | **~61% less work, repeatable** |
| same — wall clock, ms | 4804 | **3200** | **~33% faster** |
| 10 keystrokes in the tab search, 120 tabs — task time, ms | 1110 | **347** | **~69% less work, repeatable** |
| same — wall clock, ms | 1365 | 978 | ~28% faster |
| layout passes, 20 closes | 11 | 20 | more passes, each far cheaper |
| style recalcs, 20 closes | 19 | 62 | more passes, each far cheaper |
| layout passes, 10 keystrokes | 10 | 11 | unchanged |
| style recalcs, 10 keystrokes | 45 | **18** | **60% fewer** |
| 50 open/close cycles — heap after GC, KB | 991.9 → 1378.3 | 1011.3 → 1382.4 | same drift, no new leak |
| 50 open/close cycles — DOM nodes | 135 → 141 | 136 → 142 | unchanged |
| switch between two tabs on the same URL — page requests | 0 | 0 | the frame was never reloaded, before or after |
| localStorage writes / bytes per tab close | 1 / 1828 | 1 / 1828 | unchanged |
| DOM nodes on the start page | 67 | 67 | unchanged |
| localStorage writes / bytes per navigation | 1 / 494 | 1 / 494 | unchanged |

The layout and style-recalc *pass counts* rise on the close workload while the total
main-thread time falls by 61%: the old code replaced the whole sheet body (one big pass),
the new code invalidates a single card (a few small passes). Task time is the metric that
says which one costs the phone less.

Pixel proof: **10/10 screens byte-identical** (start, search, settings, tabs, live page,
private, dark, menu, tilted, motion off). Behaviour suite: **36/36 checks, zero JS errors**,
on both sides.

**Applied (10).** Card nodes on the tab sheet are reused: the sheet parses its cards once on a
full build and afterwards updates only the cards that changed, walking the list once and
moving or dropping individual nodes; closing a tab removes just that card and moves the
active highlight instead of re-rendering the rest; `duplicate` takes the same path instead of
rebuilding the sheet; the card map is emptied and re-registered on every full build, so a
closed tab's card is dropped from it and nothing retains it; the sheet still returns to the
top on a redraw, and that reset now happens before the first DOM write instead of forcing a
layout after it; `closeTab` resolves the closed tab's URL once instead of three times; the
`closed` list is capped in place instead of reallocated on every close; replacing the last tab
no longer renders and saves twice; `closed` is sanitised on load, before anything reads it;
consecutive duplicate history entries are no longer pushed; `sw` and `dup` ignore a stale tab
id and the tab-search input handler returns when no sheet is open, instead of throwing.

**Audited, no change made (3).** The iframe is shared by all tabs, so there is no per-tab
frame to free on close: the closed tab's document is already torn down by the next render,
and the 50-cycle heap measurement above shows no growth from closing. Switching to a tab
that is already on screen already skips the frame write, and the network counter confirms
zero requests during a switch. Per-tab scroll restoration was not added — it would be new
behaviour, not an optimisation.

**Reworked the same day (2), before release.** The first reconciler built each new card with
its own `createElement` + `innerHTML`, which made *opening* a large tab sheet slower than the
old single parse (20 closes: 2107 ms of task time against 1487 ms before); the sheet now
parses all its cards in one `innerHTML` on a full build and reconciles only on later redraws.
The first version also read `scrollTop` after mutating the sheet, forcing a layout on every
redraw; the reset now happens before the first DOM write, so the sheet still returns to the
top exactly as it did, without the forced flush.

**Harness note.** The keystroke workload first captured `#tq` once, which silently measured
nothing on the old build: the old code replaces that input element on every redraw, so the
captured handle went stale after the first keystroke. The workload re-queries the input each
time; the numbers above are from the corrected workload.

A screen that differs is re-rendered up to four times and only counted as differing if the
difference reproduces — headless compositing jitters a backdrop sample occasionally, and on
one of the stability runs two renders of the *same* file differed by 24 px on the rounded
corners of the address bar (max channel delta 3). It did not reproduce, and a deliberate
one-pixel change reproduced on every attempt, so the retry distinguishes jitter from a real
change rather than hiding one.

APK rebuilt and re-signed: **61 026 bytes** (was 59 666), the asset inside byte-identical to
`GlassBrowser/Glass_Browser.html` (SHA-256 `cc944f638413bdc5…`). JAR scheme v1 (9 entries
digested, PKCS#7 over `GLASS.SF`) and APK Signature Scheme v2 (single 1 MB chunk, 32-byte
digest, RSA-SHA256, signing block magic intact) both verify with the checker written from the
platform spec — that same checker validates the previous artefact completely (v1 and v2), so
it is not simply agreeing with today's signer. The repo carries no key material, so this
build was signed with a freshly generated self-signed key, as on the earlier days.

## Day 14 — 14 Nov 2026 (v1.0.6)

Caching and network. *(This file has no day-9 to day-13 sections — the run resumed at
day 14, so the release number continues from v1.0.5.)* Every change is in the script: the
markup and the stylesheet are byte-identical to day 8. Numbers are medians where a median
means anything; request counts are exact and repeat on every run.

| Workload | Before | After | Verdict |
| --- | --- | --- | --- |
| requests made by the shell at boot | 1 document, 0 subresources | 1 document, 0 subresources | unchanged (nothing to remove) |
| frame navigations to `about:blank` at boot | 2 | **1** | **one fewer document load** |
| Reader View opened twice on the same page — requests to that page | 1 (served from the disk cache) | **0** | **no request at all on the second open** |
| Reader View re-opened while the first fetch is in flight — requests | 2 | **1** | **half, deterministic** |
| Reader View across a redirect, opened twice — requests | 4 (`/redir`, `/site.html`, `/redir`, `/site.html`) | **2** (`/redir`, `/site.html`) | **half, deterministic** |
| `Referer` sent on the reader fetch | `http://…/old.html` | **none** | the shell's own URL is no longer disclosed |
| `Cookie` sent on the reader fetch | none | none | unchanged (`credentials:"omit"` already held) |
| cookies present after a session | 1 | 1 | unchanged — the visited page's own cookie |
| `#prog` class writes over four navigations | 10 | **8** | two redundant style writes removed |
| DOM nodes on the start page | 87 | 87 | unchanged |
| localStorage bytes for the same state | 2084 | 2084 | unchanged |

Pixel proof: **11/11 screens byte-identical** (start, search, settings, tabs, live page,
private, dark, menu, tilted, motion off, reader). The harness was proved stable and
sensitive before it was trusted: two independent runs of the unchanged page were
byte-identical on all screens, and two deliberate sub-pixel-class changes were each caught
— a 1 px toolbar shift on 9 of 11 screens (invisible on `private`, where the focused
address bar hides the toolbar, and on `reader`, where the overlay covers it) and a
16 px → 15.9 px body font on 9 of 11 (the live page's chrome text is unchanged by it).
Every screen is caught by at least one of the two. Behaviour suite: **50/50 checks, zero
JS errors**, on both sides.

**Applied (6).** `blank()` no longer navigates the frame to `about:blank` when the frame has
never held a document — the initial `src` attribute is absent and an iframe with no `src`
already shows an empty document, so the write was a round trip that painted nothing (boot
now shows one `about:blank` navigation instead of two, and every search page saves one
too); Reader View keeps a bounded eight-entry map of extracted article bodies, keyed by the
requested URL *and* by the final URL after redirects, so a second open of the same page —
including one reached through a redirect — costs no request and no parse; a second open
while the first fetch is still in flight reuses that promise instead of issuing a second
request; a response token plus an open check means a response for a page you have left, or
for a reader you have already closed, cannot paint over what you are looking at; the reader
fetch now carries `referrerPolicy:"no-referrer"`, matching the frame's own
`referrerpolicy="no-referrer"`, so the shell's URL is not sent to the page being read; the
reader cache is dropped by "Clear browsing data", and `progress`/`progDone`/`progClear`
write the class only when it actually changes.

**Audited, no change made (4).** The shell makes no network call of its own: loading it
issues exactly one document request and zero subresources, and a grep of the file finds no
font, image or script URL — the four `https://` strings in it are search-engine templates
that only build a link when tapped. Cache headers on the served asset were checked and do
not apply: the shell is read from the app bundle (`assets/` inside the APK on Android,
`loadFileURL` on iOS) and never over HTTP, so there is no response to attach a validator
to; when it is served over HTTP it is one self-contained document with no subresources to
cache. The offline and DNS-failure paths were measured rather than assumed: a navigation to
an unresolvable host fires `load` on the frame with the browser's own error page, so the
progress bar completes instead of hanging, and the error path costs no extra work — no
change was needed. Blocked hosts still render their card without any navigation, so the
frame never requests them.

**Reverted the same day (1).** The reader extraction was rewritten to stop after the sixtieth
heading or paragraph instead of materialising every `h1`/`p` on the page and slicing the
result. It was measured three ways and it is not a win: the two algorithms run over a
20 000-paragraph document take **0 ms each** in isolation, and opening Reader View on that
page interleaved between the two builds gave 2421 ms before against 1883 ms after with
wholly overlapping ranges (942–3169 against 1380–3351). The original expression is back in
place and the day ships without it.

**Harness notes.** Three sources of false difference were found and eliminated before the
proof was trusted. A blinking text caret is a 1 Hz animation, so a screenshot caught it in a
random phase and, through the address bar's backdrop sample, moved tens of thousands of
pixels; the harness now renders both builds with `caret-color:transparent` injected
identically into both. A glass sheet's backdrop sample takes up to ~2.5 s to converge in
headless Chromium, so the harness shoots until two consecutive frames are byte-identical
rather than trusting a fixed wait. A real mouse click also emits a `pointermove`, which
starts the tilt spring and leaves the decorative orb's scale depending on a race — the app
handles every control through a delegated click listener, so the harness drives it with
synthetic clicks and no pointer motion at all. The pod has 2 GB and ten glass screens in one
browser eventually OOM the renderer, so each screen gets its own browser; both builds still
share one top-level document inside a screen, which is what keeps their renderer state
identical.

APK rebuilt and re-signed: **60 381 bytes** (was 61 026), the asset inside byte-identical to
`GlassBrowser/Glass_Browser.html` (SHA-256 `fde859922e3261d9…`). Every other entry —
manifest, resources, the five launcher icons, `classes.dex` — is byte-identical to the
previous artefact and in the same order. JAR scheme v1 (9 entries digested, SHA-256 manifest
digest in `GLASS.SF`, detached PKCS#7 over `GLASS.SF`) and APK Signature Scheme v2 (one
1 MB chunk, 32-byte digest record, RSA-SHA256 PKCS#1 v1.5, 2048-bit) both verify with a
checker written from the platform specification: it recomputes the content digest from the
signed file, verifies the RSA signature over the signed-data block including its length
prefix, checks the embedded certificate's public key against the one in the signer record,
recomputes all nine entry digests against `MANIFEST.MF` and verifies the PKCS#7 signature
over `GLASS.SF`. The same checker rejects a copy of today's APK with one byte of the asset
flipped (content digest mismatch) and cannot parse the previous artefact's v2 block at all,
which carried a single bare digest record rather than the signed-data structure — so it is
not simply agreeing with today's signer. The repo carries no key material, so this build was
signed with a freshly generated self-signed key, as on the earlier days.
