# Changelog — Eckbauer Theme

## 1.2.0 — 2026-06-14

### Added
- Collapsible sidebar toggle on mobile: `#primary` widget area is hidden behind a full-width "Seitenleiste" button. CSS flexbox order pulls the button above the article list so it is reachable without scrolling.

### Fixed
- TablePress tables no longer cropped on the right side on narrow viewports; wide tables now scroll horizontally inside a wrapper div.

## 1.1.0 — 2026-05-14

### Added
- Cache-busting for the child theme stylesheet via WordPress version query string.
- Per-comment visibility toggle: admins can hide individual comments from guests via a checkbox in the comment edit screen and the inline reply form.

### Changed
- Comment sections on marked posts are hidden from guests entirely (post-level toggle in the sidebar meta box).

## 1.0.0 — initial release

- Child theme of Twenty Ten with BSG Eckbauer branding (gold/charcoal palette, club banner).
- Responsive layout for Twenty Ten: fluid width, collapsible hamburger navigation with submenu toggles, horizontal scroll for wide tables.
- Guest-only comment hiding at post level.
