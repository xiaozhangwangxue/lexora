# 005 — Keep search feedback responsive and physical

- **Status**: DONE
- **Commit**: `2ff81a3`
- **Severity**: HIGH
- **Category**: Physicality, performance, accessibility
- **Estimated scope**: 2 files, about 35 lines

## Problem

The new add/remove affordance scales its icon from zero:

```dart
// apps/lexora/lib/screens/search_screen.dart:533 — current
AnimatedSwitcher(
  duration: const Duration(milliseconds: 180),
  switchInCurve: const Cubic(.23, 1, .32, 1),
  transitionBuilder: (child, animation) => ScaleTransition(
    scale: animation,
    child: FadeTransition(opacity: animation, child: child),
  ),
)
```

Scaling from zero makes the plus/check look as if it appears from nowhere. The
transition also continues moving when the operating system requests reduced
motion. Search is a high-frequency surface, so suggestion rows correctly appear
without decorative animation and must remain that way.

The macOS sidebar already uses the correct 260 ms spatial curve:

```swift
// apps/lexora/packaging/macos/MainFlutterWindow.swift:180 — current
.timingCurve(0.77, 0, 0.175, 1, duration: 0.26)
```

but its label move transition does not branch for Reduce Motion.

## Target

- Morph plus/check with opacity and scale `0.92 → 1`, never `0 → 1`.
- Use 160 ms and `Cubic(0.23, 1, 0.32, 1)`.
- When `MediaQuery.disableAnimations` is true, keep a 120 ms opacity crossfade
  but remove scaling.
- Keep live suggestion insertion animation-free.
- On macOS, replace sidebar label movement with opacity-only when
  `accessibilityReduceMotion` is enabled.

## Repo conventions to follow

- Strong UI entrance curve:
  `const Cubic(.23, 1, .32, 1)` in
  `apps/lexora/lib/screens/settings_screen.dart`.
- Spatial sidebar curve:
  `.timingCurve(0.77, 0, 0.175, 1, duration: 0.26)` in
  `apps/lexora/packaging/macos/MainFlutterWindow.swift`.
- Flutter shell already checks `MediaQuery.disableAnimationsOf(context)`.

## Steps

1. In `apps/lexora/lib/screens/search_screen.dart`, read
   `MediaQuery.disableAnimationsOf(context)` around the add/remove icon.
2. Set the switch duration to 160 ms normally and 120 ms for reduced motion.
3. For normal motion, drive `ScaleTransition.scale` with
   `Tween<double>(begin: .92, end: 1).animate(animation)` and retain the fade.
4. For reduced motion, return only `FadeTransition`.
5. In `apps/lexora/packaging/macos/MainFlutterWindow.swift`, read
   `@Environment(\.accessibilityReduceMotion)` and use opacity-only label
   transitions when enabled. Do not change page navigation or sidebar widths.

## Boundaries

- Do NOT animate suggestion rows, typed characters, search submission, or
  result loading.
- Do NOT add a motion dependency.
- Do NOT change search data, layout, labels, or navigation behavior.
- If cited code has drifted, stop and report instead of improvising.

## Verification

- **Mechanical**: run `flutter analyze`, `flutter test`, and compile the macOS
  Swift shell.
- **Feel check**:
  - Tap add/remove repeatedly; the icon must retarget cleanly and never vanish
    to a point.
  - Type quickly; suggestions must keep up without stagger or entrance motion.
  - Enable Reduce Motion; add/remove still crossfades but does not scale, and
    sidebar labels do not slide.
- **Done when**: the high-frequency search path has no decorative delay, the
  state morph stays under 200 ms, and reduced-motion mode has no spatial
  movement.
