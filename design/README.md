# Nudgebar — Design

Canonical, self-contained HTML mockups for Nudgebar's brand and UI surfaces. Each
file is standalone (inline CSS/SVG, Geist via Google Fonts) — open directly in a
browser or serve the folder.

This directory is the committed source of truth for the design. The Figma file holds
the same surfaces as captured frames; `.claude/showcases/` holds local scratch copies
used during iteration and is gitignored.

## Surfaces

| File                 | Surface                                                                                                           |
| -------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `brand-book.html`    | Brand book — essence, wordmark, logo system, color, type, icons, UI surfaces, tone                                |
| `alert.html`         | Full-screen alert — single (video + in-person), unified multi-event block, snooze, countdown, backdrop comparison |
| `popover.html`       | Menu-bar popover — hybrid hero-pair + compressed timeline (locked), plus A/B/C/D variant explorations             |
| `settings.html`      | Settings window — General, Connectors (7 providers), Alerts                                                       |
| `icons.html`         | Icon system — 8 core icons, outlined-hairline (locked)                                                            |
| `urgent-states.html` | Urgent logo state — 4 treatments at production sizes (V1 enlarged-center locked)                                  |

## Locked decisions

- **Wordmark** — `Nudgebar.` Geist 600, mixed case, blush terminal period.
- **Logo** — Bold States Ring. Four corner dots are the structural constant; the
  center changes by state. Idle = 4 dots. Active = + center dot. Urgent (V1) =
  center swells to r22 + two halos. App icon uses the urgent state.
- **Color** — Ink `#2D2520` bg, Ember `#3A2F28` surface, Blush `#FFD6CC` label/accent,
  Sand `#C7B6A8` secondary, Stone `#A6968A` tertiary. Calendar accent colors come from
  the user's calendar source, never brand-originated.
- **Type** — Geist only, six-step scale (Display 48 → Eyebrow 11).
- **Icons** — outlined hairline, 24px viewBox, 1.6px stroke, rounded caps.
- **Alert backdrop** — translucent + blur, warm copper-shifted tint, blush edge halo.
- **Popover** — hybrid: hero pair (next 1-2 actionable events with Join) over a
  compressed timeline (rest of today + tomorrow, quiet hours folded).

## Figma

https://www.figma.com/design/aLvbpC4z2upsUlQviB4iJ3
