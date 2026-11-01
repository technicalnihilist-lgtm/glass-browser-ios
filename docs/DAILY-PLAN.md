# 20-day improvement plan — 1 to 20 November 2026

**The rule, and it does not bend:** the UI stays pixel-identical and no feature is added,
removed or reworded. Every change is performance, robustness or memory work underneath.
Ten changes a day, one release a day.

## How each day is verified

1. **Pixel proof.** Every screen (start, search, settings, tabs, private, dark, a live page,
   motion) is rendered in Chromium at 390×844 before and after the day's changes and compared
   byte-for-byte. Any pixel difference fails the day.
2. **Behaviour proof.** The scripted suite runs: search flow, bookmark add/remove, tab
   create/duplicate/close, private tabs, reading list add/remove, history, settings persistence
   across reload, blocked-host card, iframe load of a live site. Zero JS errors required.
3. **Budget check.** `requestAnimationFrame` frame time while tilting, DOM node count, and
   localStorage bytes written per action are recorded in `docs/benchmarks.md` so day 20 can
   prove the total gain.

If a change can only be verified visually, it is not made. If a change fails either proof, it
is reverted the same day and logged.

---

## Week 1 — the JavaScript hot paths

**Day 1 — selector and state layer**
1. Memoise `$()` so repeated `querySelector` calls hit a Map instead of the DOM.
2. Coalesce `save()` into one `localStorage` write per animation frame.
3. Coalesce the address-bar suggestion rebuild with `requestAnimationFrame`.
4. Memoise `host()` (called for nearly every row and title).
5. Memoise the per-row date formatting in the history list. *(The originally planned
   `drawSheet()` coalescing was implemented, measured, and reverted the same day: it made the
   sheet appear one frame later without saving any work.)*
6. Cache the resolved theme and reuse a single `matchMedia` instance.
7. Add `contain: paint` to the decorative `#orb` layer.
8. Coalesce the address-bar suggestion rebuild into one animation frame.
9. Throttle pointer-driven tilt to one update per frame.
10. Throttle the toolbar hit-test to one per frame.

**Day 2 — render pipeline**
1. Add a dirty flag so `render()` is a no-op when nothing changed.
2. Split `render()` into independent theme, chrome and content passes.
3. Rebuild results HTML only when the query or result set actually changed.
4. Batch class toggles instead of interleaved read/write.
5. Cache the resolved theme instead of re-reading `matchMedia` on every render.
6. Defer the progress-bar restart to the next frame.
7. Drop redundant `theme()` calls from non-theme paths.
8. Guarantee one save per user action, not one per state mutation.
9. Remove `Object.assign` copies from the save path.
10. Make history trimming amortised instead of a slice on every push.

**Day 3 — events and input**
1. One delegated listener map, no per-render listeners.
2. Mark every scroll and pointer listener `passive`.
3. Throttle `pointermove` handlers to one per frame.
4. Debounce the tab-search input.
5. Remove the double `closest()` walk in the delegated click handler.
6. Guard `keydown` handling behind a single `Escape` check.
7. Avoid re-querying `#addr` in the focus/blur handlers.
8. Coalesce `deviceorientation` bursts into one tilt update per frame.
9. Stop the motion listener while the tab is hidden.
10. Cache `document.activeElement` checks.

**Day 4 — storage and state**
1. Version the saved schema so future migrations are free.
2. Write only changed slices instead of the whole object.
3. Cap and prune `hist` in place rather than reallocating.
4. Store tab stacks compactly.
5. Lazy-parse saved state; skip parse when the key is absent.
6. Guard against quota errors with a trimmed-state retry.
7. Debounce writes during rapid typing.
8. Drop the duplicate filter pass on load.
9. Skip `JSON.stringify` when the serialised value is unchanged.
10. Add a cheap integrity check on load and fall back to defaults.

**Day 5 — paint and compositing**
1. Audit every `backdrop-filter` surface for overdraw.
2. Promote the animated layers to their own compositor layer.
3. Remove filters from off-screen surfaces.
4. Constrain shadow repaint to the elements that move.
5. Replace animated box-shadow with a transform where visually identical.
6. Trim the number of blurred layers behind the toolbar.
7. Keep `will-change` only on elements that actually animate.
8. Avoid layout-triggering properties in the tilt loop.
9. Check paint counts with the devtools timeline.
10. Verify the pixel diff after each of the above.

**Day 6 — blur budget**
1. Measure blur cost per frame on the heaviest screen.
2. Reduce the blur radius only if the pixels are unchanged (they will not be — so instead).
3. Cache the backdrop sample for static surfaces.
4. Avoid re-compositing the orb on every tilt frame.
5. Use a static gradient fallback while dragging.
6. Check for filter stacking on nested glass.
7. Confirm no filter applies to the hidden views.
8. Profile on a throttled CPU to approximate a mid-range phone.
9. Keep the glass value the user chose as the source of truth.
10. Record the frame-time gain in the benchmark table.

**Day 7 — animation smoothness**
1. Move tilt maths to a single rAF loop with delta-time.
2. Clamp spring values to avoid overshoot work.
3. Skip the loop entirely when motion is off.
4. Stop the loop when the app is backgrounded.
5. Round transform values to 3 decimals to avoid needless style writes.
6. Skip style writes when the value did not change.
7. Verify identical easing curves.
8. Test the fastest and slowest animation-speed settings.
9. Check the pill slide animation for reflow.
10. Log the frame-time budget.

---

## Week 2 — the shells

**Day 8 — tab lifecycle**
1. Close tabs without re-rendering all cards.
2. Reuse card DOM nodes on the tab sheet.
3. Free iframe content on tab close.
4. Avoid reloading the frame when switching to an already-loaded tab.
5. Keep the active tab's scroll position.
6. Drop stale entries from `closed` before they are read.
7. Prevent duplicate history entries on the same URL.
8. Check memory after 50 open/close cycles.
9. Verify private tabs never touch storage.
10. Confirm identical visuals on the tab sheet.

**Day 9 — the iframe and page loading**
1. Set the frame `src` only on real navigation.
2. Avoid the `about:blank` round trip when nothing was loaded.
3. Stop the progress bar on error, not only on load.
4. Keep the previous page visible until the next one paints.
5. Test slow and failing navigations.
6. Check the blocked-host path for wasted work.
7. Verify the reader view does not fetch twice.
8. Confirm the frame keeps its sandbox attributes.
9. Check reload behaviour after a failed load.
10. Log timings for a cold navigation.

**Day 10 — Android shell**
1. Tune WebView renderer priority.
2. Disable unused WebSettings features.
3. Trim the asset read to a single allocation.
4. Verify the intercept path adds no measurable latency.
5. Check the back-button animation cost.
6. Confirm the virtual origin serves in one request.
7. Measure cold start on a low-end profile.
8. Check memory after backgrounding.
9. Keep the APK size flat or smaller.
10. Rebuild, re-sign, re-verify.

**Day 11 — iOS shell**
1. Trim WKWebView configuration to what is used.
2. Load the page off the main thread.
3. Avoid a second load on scene re-entry.
4. Check the back-button overlay for layout passes.
5. Verify safe-area handling is unchanged.
6. Measure first-paint time.
7. Check memory warnings behaviour.
8. Confirm the same pixel output as Android.
9. Keep the project file valid.
10. Update the repo notes.

**Day 12 — cold start**
1. Measure time to first paint, three runs.
2. Defer non-critical script work until after first paint.
3. Trim the parse cost of the initial render.
4. Avoid the redundant first render.
5. Pre-size the initial DOM writes.
6. Check the cost of the saved-state parse.
7. Confirm identical first frame.
8. Log the numbers.
9. Repeat on a throttled CPU.
10. Publish the before/after in the benchmark table.

**Day 13 — memory**
1. Snapshot the heap on each screen.
2. Remove detached-node leaks.
3. Free closed-tab data.
4. Cap the suggestion cache.
5. Check the selector Map for unbounded growth.
6. Verify listener counts stay flat across 100 interactions.
7. Check the audio context is reused, not recreated.
8. Confirm no timers survive a closed tab.
9. Record peak heap per screen.
10. Confirm visuals unchanged.

**Day 14 — caching and network**
1. Verify no network call is made by the shell itself.
2. Check cache headers on the served asset.
3. Avoid re-fetching the page on restore.
4. Confirm the iframe gets normal caching.
5. Check offline behaviour.
6. Verify the error path when DNS fails.
7. Trim redundant redirects.
8. Confirm no cookie growth.
9. Log request counts per session.
10. Confirm the visuals.

**Day 15 — error handling**
1. Wrap the storage layer in a single guard.
2. Handle a corrupted saved state.
3. Handle a missing asset with a clear message.
4. Handle a dead renderer without losing state.
5. Catch audio failures silently.
6. Guard the share and clipboard paths.
7. Confirm no unhandled promise rejections.
8. Add a self-check that runs on boot.
9. Log errors locally, never to a server.
10. Confirm the UI is unchanged in the happy path.

**Day 16 — edge cases**
1. Very long URLs and titles.
2. Empty and whitespace-only queries.
3. 200 tabs.
4. Zero bookmarks, zero history.
5. Rapid tapping.
6. Rotation mid-animation.
7. Keyboard open and close.
8. Low storage.
9. Deep-link entry.
10. Confirm the visuals in each case.

**Day 17 — accessibility (no visual change)**
1. Confirm every control keeps its label.
2. Check focus order.
3. Confirm `aria-expanded` stays in sync.
4. Check reduced-motion handling.
5. Confirm contrast is untouched.
6. Verify the live region still announces.
7. Check keyboard reachability of the sheet.
8. Confirm the app still works at 200% font scale.
9. Verify nothing new is focus-trapping.
10. Confirm the pixels.

**Day 18 — battery and background**
1. Stop all loops when backgrounded.
2. Stop sensor listeners when hidden.
3. Check wake-ups per minute.
4. Verify the audio context suspends.
5. Confirm no work on a hidden tab.
6. Measure drain over a fixed script.
7. Confirm resume restores the frame.
8. Check the tilt loop restart.
9. Log the numbers.
10. Confirm the visuals.

**Day 19 — benchmarks and regression net**
1. Freeze the benchmark script into the repo.
2. Record every metric from days 1 to 18.
3. Add the pixel-diff harness to the repo.
4. Add the behaviour suite to the repo.
5. Write the run instructions.
6. Prove the UI never moved across the whole run.
7. Publish the total gain table.
8. List every change made, day by day.
9. Flag anything deferred.
10. Confirm the release builds still verify.

**Day 20 — audit and final release**
1. Re-run every proof end to end.
2. Confirm zero visual diffs across all 20 days.
3. Confirm zero feature changes.
4. Re-check the APK signature and size.
5. Re-check the iOS project parses.
6. Update the README and store notes.
7. Tag the final release.
8. Update the Orion submission with the new version.
9. Write the summary of the 200 changes.
10. Hand over the release notes.

---

## Release discipline

- One release per day: `v1.0.1` … `v1.0.20`, each with the day's ten changes in the notes.
- The Orion Store entry tracks the latest release automatically, so no re-submission is needed.
- Nothing is published unless both proofs pass.
