# Flutter Web E2E Selector Policy

## Text Input
- Always target: `input[aria-label="<VisibleLabel>"]`
- Never type into semantics proxy inputs
- Always click before typing
- Always use keyboard typing (never fill)

## Buttons
- Prefer: `button:has-text("<VisibleText>")`
- Fallback: `[role="button"]:has-text("<VisibleText>")`

## Assertions
- Prefer visible text
- Avoid URL-only assertions
- Avoid aria-label assertions for navigation

## Timing
- Always wait for visibility
- Allow small delays for Flutter focus transitions (200-500ms)
