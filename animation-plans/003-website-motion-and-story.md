# Website motion and story: calm hierarchy, clear feedback

## Audit metadata

- Baseline commit: `43987f2`
- Surfaces:
  - `app/page.tsx`
  - `app/globals.css`
  - `app/lexora-wordmark.tsx`
- Priority: P1
- Status: DONE

## Current behavior

- The hero wordmark has a long looping gradient animation, while most cards and calls to action either jump instantly or use an undifferentiated `transition: .2s`.
- Download cards and donation cards move upward on hover, but buttons do not share a consistent pressed response.
- Reduced-motion handling covers only the wordmark and platform cards.
- Two consecutive donation sections repeat the same message and interrupt the product story.
- Product copy describes only PDF, EPUB, and DOCX, so it no longer explains the image, long-image, or intelligent compact-layout workflow.

## Problems

- Motion does not consistently explain hierarchy or interaction state.
- Infinite hero animation attracts attention after the brand has already been understood.
- Broad transitions can animate unintended properties and make later responsive changes less predictable.
- The repeated donation block weakens the ending, while new export and layout capabilities are absent from the introduction.

## Implementation

1. Introduce shared motion tokens: 140 ms pressed feedback, 220 ms small-state transitions, 280 ms larger surface transitions, `cubic-bezier(.23,1,.32,1)` for entrances and `cubic-bezier(.77,0,.175,1)` for spatial movement.
2. Make the hero wordmark entrance continuous with its initial rendered state, then run the color signal only once. Do not loop decorative motion.
3. Add a small client-side reveal observer for the statement, feature, download, and donation groups. Animate only opacity and a restrained vertical transform; reveal immediately when reduced motion is requested or JavaScript is unavailable.
4. Give primary buttons, download choices, demo controls, and donation cards a consistent hover/focus treatment and a 0.97 pressed scale. Gate hover motion behind `(hover:hover) and (pointer:fine)`.
5. Remove the first donation section and keep the final QR-channel section as the single closing support moment.
6. Rewrite the hero, process, and export copy to explain imports, five output modes, reliable EPUB reflow, and intelligent compact layout without adding another long section.
7. Expand `prefers-reduced-motion` coverage to every reveal, transition, and decorative animation.

## Acceptance

- The page is fully readable before animation and remains fully usable without JavaScript.
- No looping decorative animation remains in the hero.
- Interactive feedback completes within 300 ms and pressed controls never disappear or scale from zero.
- Hover-only movement does not run on touch devices.
- Reduced-motion mode contains no spatial entrance animation or smooth scrolling.
- The home page contains one donation section and clearly introduces image, long-image, EPUB, DOCX, PDF, and smart compact layout exports.
