# Lexora 1.2.0 Design QA

## v1.2.0 macOS sidebar comparison

- Reported source: `/tmp/lexora-sidebar-reference.png`
- Corrected implementation: `/tmp/lexora-v120-qa/build/qa/macos-onboarding-after.png`
- Combined comparison: `/tmp/lexora-onboarding-comparison.png`
- Viewport: 1594 x 1332 for both source and corrected render
- State checked: fresh install, onboarding visible before the main application shell

### Fidelity review

1. The source showed a 435-pixel gray native sidebar material behind the opaque onboarding flow. The corrected render uses one continuous onboarding surface across the full window; the phantom sidebar is absent.
2. Existing Lexora spacing, lavender primary color, rounded icon panel, progress dots, Skip action, and full-width primary action are preserved. No new visual language or replacement assets were introduced.
3. The comparison harness uses Flutter's test font, so text appears as measurable glyph blocks in the corrected capture. Production builds continue to bundle the existing Noto font assets; this is not a production rendering defect.
4. The compact desktop sidebar now reveals labels only after the animated width can contain them. Automated mid-transition inspection found no overflow, and the nonlinear 460 ms curve remains continuous in both directions.

### Findings

- P0: none
- P1: none
- P2: none

### v1.2.0 final result

final result: passed

---

## Archived Lexora 1.1.2 Design QA

## Evidence

- Source truth: `/tmp/lexora-website-animation-start.png`
- Android defect source: `/tmp/codex-remote-attachments/019f57fb-5323-7671-a00c-f412ce3f857e/b0725dc5-d7c2-4a69-a722-537df09dcd1a/1-Photo-1.jpg`
- Android resumed implementation: `/tmp/lexora-v112-qa3/apps/lexora/build/qa/android-resume-after.png`
- Desktop initial state: `output/playwright/website-v1.1.2-animation-start-final.png`
- Desktop settled state: `output/playwright/website-v1.1.2-desktop-final.png`
- Mobile settled state: `output/playwright/website-v1.1.2-mobile-spacing-final.png`
- Live mobile after Cloudflare routing fix: `/tmp/lexora-v112-qa3/output/playwright/website-v1.1.2-live-mobile-recheck.png`
- Live desktop after Cloudflare routing fix: `/tmp/lexora-v112-qa3/output/playwright/website-v1.1.2-live-desktop-restored.png`
- Viewports: Chrome at 1440 x 1000 and 390 x 844; Flutter Android harness at 540 x 1280
- States checked: first rendered frame, completed wordmark animation, responsive mobile layout, Android keyboard open -> launcher -> app resume -> Settings
- Browser console: no errors
- Android regression conditions: a 480-pixel stale keyboard inset was deliberately retained after resume

## Fidelity review

1. Typography: the Lexora wordmark retains the intended Manrope weight, color split, and baseline. Mobile uses a dedicated -0.06em tracking value so the letters remain distinct without losing the compact identity.
2. Layout and spacing: the wordmark, pronunciation, eyebrow, headline, copy, and calls to action remain centered and visually balanced at both viewports. No clipping or horizontal overflow was observed.
3. Color and effects: ink, blue, and mint brand colors match the established identity. The first animation frame is intentionally close to the resting frame, with only a subtle two-pixel lift and small opacity change.
4. Imagery and iconography: the existing application icon remains in the upper-left navigation, and official platform icons and existing brand assets are preserved.
5. Responsive interaction: the mobile wordmark has a separate animation endpoint, preventing the desktop tracking value from being reapplied when the animation completes. Reduced-motion behavior remains available.

## Android resume comparison

- Full-view evidence: the source screenshot shows Settings clipped at the example selector while a former keyboard-sized area remains reserved. The post-fix 540 x 1280 render keeps the root scaffold and bottom navigation at full screen height and renders the Quick Links card below PDF customization.
- Focused-region evidence: no additional crop was needed because the failure and fix are both visible in the full-height relationship between the PDF card, Quick Links card, empty lower canvas, and persistent navigation.
- Typography: the headless Flutter capture lacks the production Chinese font rasterization and therefore shows tofu glyphs; component sizes, wrapping constraints, and hierarchy remain measurable. Production font assets were not changed.
- Spacing and layout rhythm: the stale IME inset no longer shortens the root layout. Card radii, horizontal margins, section gaps, and navigation placement remain consistent with the established Android screen.
- Colors and visual tokens: the light surface, lavender intro card, white settings cards, primary selection tint, and semantic quick-link colors are preserved.
- Image quality and asset fidelity: the existing Lexora wordmark and GitHub control remain in their original components; no image or icon asset was replaced for this fix.
- Copy and content: all Settings labels, controls, and quick links remain present; only lifecycle and inset behavior changed.

## Comparison history

- Earlier P1: returning from the launcher with a stale Android IME inset clipped Settings and reserved a large blank region.
- Fix: dismiss the keyboard on every non-resumed lifecycle state, repeat the synchronization after resume, and keep the Android app shell at full height instead of resizing from a potentially stale inset.
- Post-fix evidence: the dedicated lifecycle test passes with a 480-pixel stale inset, clears the input focus, keeps `resizeToAvoidBottomInset` disabled for Android, and measures the navigation bottom at y = 1280.
- Earlier live P0: a broad Cloudflare `run_worker_first: true` rule caused website CSS and JavaScript assets to pass through the application Worker and render the deployed site without styling.
- Fix: narrow Worker-first asset routing to `/version.json` only. Update and download routes continue to fall through to the Worker when no static asset exists, while CSS, JavaScript, fonts, and images remain on Cloudflare Assets.
- Post-fix evidence: the final live mobile and desktop captures render the complete branded layout, and the R2 manifest still exposes verified sizes and SHA-256 values.

## Findings

- P0: none
- P1: none
- P2: none

## Implementation checklist

- [x] Android background and resume lifecycle synchronization
- [x] Full-height app shell under stale keyboard inset
- [x] Regression test at the reported 540 x 1280 viewport
- [x] Full Flutter analysis and 22-test suite
- [x] Website build and rendered HTML tests

## Final result

final result: passed
