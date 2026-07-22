# Navigation and dialog motion: faster, focus-safe transitions

## Audit metadata

- Baseline commit: `0a6327a`
- Surfaces:
  - `apps/lexora/lib/screens/shell_screen.dart`
  - `apps/lexora/lib/screens/pdf_customization_dialog.dart`
- Priority: P1
- Status: DONE

## Current behavior

- Android bottom navigation uses a 300 ms emphasized page animation.
- The PDF customization dialog enters over 520 ms with `easeOutBack`, producing overshoot, and reverses with a different spatial feeling.
- The hidden home input may retain focus, allowing a page reveal and keyboard reopening when navigating between non-home tabs.

## Problem

- Repeated tab navigation should feel immediate and preserve the chosen destination.
- Overshoot makes the settings sheet feel less native and visually unstable near phone system insets.
- Motion must not be driven by the hidden text field's focus request.

## Implementation

1. Clear Android focus whenever the destination is not Home, independent of the current page.
2. Make the Home input's autofocus conditional on Home being active and clear its focus when it becomes inactive.
3. Shorten programmatic page navigation to 240 ms using `Cubic(0.32, 0.72, 0, 1)`.
4. Shorten the customization dialog to 260 ms. Use fade plus a restrained scale from 0.97 and an 8 px vertical offset, with no overshoot.
5. Use `MediaQuery.disableAnimations` to bypass decorative interpolation while preserving state changes.

## Acceptance

- History or Settings -> Generated remains on Generated and never opens the keyboard.
- The dialog never overlaps safe insets and has no bounce.
- Rapid repeated tab taps remain interruptible and land on the latest destination.
- Normal motion completes within 300 ms; reduced-motion mode is effectively immediate.

## Implementation result

Implemented across `shell_screen.dart`, `home_screen.dart`, and `pdf_customization_dialog.dart`: non-home destinations always clear Android focus, Home autofocus follows active state, tab animation is 240 ms, and the customization dialog uses a restrained 260 ms fade/scale/slide without overshoot.
