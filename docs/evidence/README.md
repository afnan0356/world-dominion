# Evidence — what could and could not be captured

## The limitation, stated plainly

**No screenshot of the running game exists for this milestone.** The environment this milestone was
built in has no GPU, no display server (`DISPLAY` unset, no X or Wayland socket), no `/dev/dri`, and no
OpenGL/Vulkan/EGL driver; the Godot build used here was compiled with `vulkan=no opengl3=no` precisely
because those drivers are absent. Export templates, Xvfb, Mesa and headless browser fallbacks were all
attempted earlier in the project and none of them produce a frame that the real renderer would draw. A
picture produced from an approximated layout rasteriser would be a diagram, not a screenshot, and it is
not labelled as one.

Attempting this again would not change the outcome, so it is not retried.

## What is in this folder instead

| File | What it is | What it proves |
| --- | --- | --- |
| `atlas-midnight.png` | A **data render**: the committed `data/world/geometry.json` rasterised with Pillow in the committed Midnight map palette, equirectangular, Bangladesh selected. Caption inside the image says `DATA RENDER — NOT AN ENGINE SCREENSHOT`. | The polygons, the projection, the hole handling, the land/water/border/selection colours and the label data are real and complete. |
| `atlas-parchment.png` | The same render in the Parchment palette. | Both themes use real, distinct map colours and both are legible. |

Both files are produced by a committed script, so a reviewer can reproduce or re-derive them:

```bash
pip install pillow
python3 tools/render_atlas_evidence.py --out docs/evidence
```

The script reads the map colours **out of `src/ui/theme/palette.gd`** rather than duplicating them, so
the images cannot silently drift from the theme.

What these renders also cannot show, because they are drawn by the Python script rather than by the
engine: the tiny-country marker rings, the ocean labels, the scale bar, the graticule brightness at
different zooms, and any label-collision behaviour. Those exist in the renderer and are asserted in
code and tests, but no picture of them taken from the running game exists.

What these renders deliberately cannot show: Control layout, fonts and text metrics, tweens and
transitions, focus rings, the dossier panel, search results, the campaign overlay, or any engine-side
rendering behaviour. Those are covered by the layout assertions in `tests/suites/test_campaign_ui.gd`
and `tests/suites/test_layout.gd`, which assert resolved rects against every reference viewport, and by
the honest statement that no visual inspection on hardware has happened yet. That verification remains
outstanding and is listed in `ROADMAP.md`.

## Earlier milestone evidence

`docs/layout-diagrams/` holds Milestone 01's layout drawings, which are labelled there as drawings.
They are not screenshots either, for the same reason.
