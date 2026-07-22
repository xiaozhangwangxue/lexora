# Document customization: native glass and bounded repainting

## Audit metadata

- Baseline commit: `43987f2`
- Surfaces:
  - `apps/lexora/lib/screens/pdf_customization_dialog.dart`
  - `apps/lexora/lib/screens/shell_screen.dart`
  - `apps/lexora/packaging/macos/MainFlutterWindow.swift`
- Priority: P1
- Status: DONE

## Problems found

- The cross-platform dialog blurred the entire scene while simultaneously animating scale, slide, opacity, keyboard padding, scrolling, and a large form.
- Every slider tick rebuilt the full dialog, including all controls and the typography preview.
- macOS rendered a Flutter approximation of glass instead of using the system material and native slider behavior.
- The compact macOS sidebar was too narrow to visually contain all three window controls.

## Implementation

1. Route document customization on macOS through the existing method channel into a native SwiftUI sheet.
2. Use native SwiftUI segmented pickers and sliders; on macOS 26+, group the typography controls in an interactive Liquid Glass container with a continuous 12 pt corner radius matching Lexora cards.
3. Keep an ultra-thin system material fallback on earlier macOS versions.
4. Remove the full-scene real-time blur from Android, Windows, and Linux. Use a single 210 ms opacity/scale transition with the same nonlinear entrance curve as the rest of Lexora.
5. Isolate each Flutter slider's state and repaint boundary so drag updates rebuild only that control and the preview, not the complete form.
6. Widen the compact native sidebar from 76 pt to 96 pt so the window controls remain visually contained.

## Acceptance

- Slider dragging does not trigger a full-dialog rebuild.
- Cross-platform opening and closing animate only opacity and scale and finish within 210 ms.
- macOS uses a native sheet and native slider interaction, with a non-glass material fallback where Liquid Glass is unavailable.
- Cancel and save both return focus without reopening the software keyboard.
- The compact macOS sidebar fully contains the three window controls.
