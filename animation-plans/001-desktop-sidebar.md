# Desktop sidebar: responsive nonlinear transition

## Audit metadata

- Baseline commit: `0a6327a`
- Surface: `apps/lexora/lib/screens/shell_screen.dart`
- Priority: P1
- Status: DONE

## Current behavior

The sidebar width animates between 76 and 220 logical pixels for 460 ms using `Curves.easeInOutCubicEmphasized`. The toggle remains visible even below the 820 px threshold where expansion is disabled. The menu glyph also rotates 180 degrees although its visual meaning does not change.

## Problem

- At widths where expansion is unavailable, the visible control suggests an action that cannot happen.
- A 460 ms layout animation feels heavy for a frequent desktop control.
- Rotating a symmetric hamburger icon adds motion without communicating state.

## Implementation

1. Pass an explicit `canToggle` flag from the shell to `_DesktopSidebar`.
2. Omit the toggle when `canToggle` is false; retain the compact navigation and version-free footer.
3. Reduce width transition to 260 ms with `Cubic(0.77, 0, 0.175, 1)` so acceleration and deceleration remain nonlinear without bounce.
4. Remove icon rotation. The sidebar width and label reveal already communicate state.
5. Preserve the existing label reveal threshold (`constraints.maxWidth >= 180`) so text cannot overflow during interpolation.

## Reduced motion

Flutter does not expose a universal desktop reduced-motion flag consistently on all supported platforms. If `MediaQuery.disableAnimations` is true, use `Duration.zero`; otherwise use 260 ms.

## Acceptance

- At 700 px, compact sidebar is usable and no toggle is present.
- At 1100 px, toggle collapses and expands the sidebar.
- No label overflow occurs during resize.
- Transition is under 300 ms and contains no overshoot.

## Implementation result

Implemented in `apps/lexora/lib/screens/shell_screen.dart`: the shell now passes `canToggle`, the unavailable control is omitted below the expansion breakpoint, the width transition uses a 260 ms nonlinear cubic, and reduced-motion mode uses zero duration.
