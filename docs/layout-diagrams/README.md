# Layout diagrams (not screenshots)

These PNGs are **diagrams, not engine renders**. No GPU, display server or OpenGL/Vulkan driver was
available in the environment this milestone was built in, so the application could not be rendered and
screenshotted (see the pull request for the full explanation and the commands that were tried).

Instead, a temporary diagnostic scene mounted each screen in a `SubViewport` at the size shown, let the
real `Control` layout settle (including opacity tweens), and dumped, for every node:

- its resolved rect, in viewport coordinates;
- its resolved theme stylebox (fill, border, corner radius) and modulate alpha, with scroll clipping;
- for text: the font file, size, tracking, colour, alignment, line spacing, autowrap mode and content;
- for icons: the SVG they come from.

That geometry was then rasterised with Pillow using the project's own font files and palette colours and
stamped "LAYOUT DIAGRAM". Rects, colours, fonts and sizes are exact; glyph rasterisation and text
wrapping are approximations, so treat these as a layout drawing rather than a picture of the app.

They are committed to give a reviewer something visual to check against, and to document the responsive
rules at the two reference sizes:

| File | Screen | Size |
| --- | --- | --- |
| `main-menu-desktop-1280x720.png` | Main menu | Desktop landscape |
| `main-menu-phone-landscape-844x390.png` | Main menu | Phone landscape |
| `settings-midnight-1280x720.png` | Settings, Midnight | Desktop landscape |
| `settings-parchment-1280x720.png` | Settings, Parchment | Desktop landscape |
| `about-desktop-1280x720.png` | About & Credits | Desktop landscape |
| `about-phone-landscape-844x390.png` | About & Credits | Phone landscape |

## Measured text diagrams (Milestone 08)

The screens added since then are documented as ASCII diagrams drawn from the rectangles the
headless tests assert, rather than as pictures:

| File | Screen | What it records |
| --- | --- | --- |
| `first-run-screen.md` | First run: loading, terms, notifications, profile | Column width, control heights, scrolling on a short window |
| `country-picker.md` | Country picker and flag strip on campaign setup | The two columns, the 340 px panel, strip tile sizes, the short-window compact form |
| `profile-screen.md` | Profile screen and the avatar grid | Identity, XP bar with numbers, the 5 × 4 grid, rename dialog, portrait behaviour |

A real visual check on hardware (or with a GPU-enabled Godot build) is still outstanding; it is listed as
an open verification item in `ROADMAP.md`.
