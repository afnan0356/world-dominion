# Animation

Every moving thing in WORLD DOMINION, what starts it, and what happens instead
when a player turns **Reduced motion** on. Written in plain language; the exact
names below are the ones used in the code.

> This file is **generated** from `AnimationTokens.CATALOGUE` by
> `python3 tools/report_animations.py`. Do not hand-edit it: edit the table in
> `src/ui/animation/animation_tokens.gd` and regenerate. CI runs
> `--check` and fails if the two disagree.

## How animation works here

One small runner, `AnimationService`, does all of it. A screen creates one for
itself, and every animation names an entry from the table below. Four rules
come out of that design, and each one has a test:

1. **Nothing blocks input.** The runner never accepts, swallows or waits for
   input; it only changes values. A camera flight is cancelled by the first
   drag, zoom or key press, so the player always wins.
2. **Nothing animates when nothing changes.** Asking for a value the target
   already has creates no tween at all, and a paused campaign runs no ambient
   animation.
3. **Every animation has a reduced-motion answer**, written in the table. Under
   reduced motion the runner applies the final value immediately and creates no
   tween; looping animations (the selection pulse, the ambient sea) do not start.
4. **Nothing flashes more than three times per second.** The table declares a
   flash rate per entry and the generator refuses to write a document that
   breaks the limit; the suite checks the same rule.

## The animations

| Name | Duration | Easing | Starts when | With reduced motion |
| --- | ---: | --- | --- | --- |
| `ambient_ocean` | 500 ms per leg, repeating | linear | The campaign clock is running and the sea is on screen. | The sea is completely still. |
| `button_press` | 90 ms | cubic out | Pressing a button. | No scale change; the button's own pressed state is enough. |
| `camera_fly` | 440 ms | cubic out | Selecting a country from search, the recent list or the dossier. | Jumps straight to the country with no camera movement. |
| `campaign_start` | 320 ms | cubic out | A campaign starts and the opening overlay fades away. | The overlay is dismissed at once; it can also be skipped at any time. |
| `panel_fade` | 140 ms | cubic out | A panel's dimming layer appears or disappears. | No fade; the layer is simply there or not. |
| `panel_slide` | 180 ms | cubic out | A panel opens or closes (map display options, pause menu). | The panel appears or disappears in place. |
| `pause_change` | 180 ms | cubic out | Pausing or resuming the clock. | The status label changes immediately. |
| `selection_pulse` | 1200 ms per leg, repeating | cubic out | A country is selected while motion is allowed. | The selection outline is drawn once, at a fixed weight. |
| `speed_change` | 160 ms | cubic out | Changing the simulation speed. | The speed label changes immediately. |

## Where each one is used

| Name | Call sites |
| --- | --- |
| `ambient_ocean` | `src/ui/map/world_map_view.gd` |
| `button_press` | `src/ui/components/press_feedback.gd` |
| `camera_fly` | `src/ui/map/world_map_view.gd` |
| `campaign_start` | `src/ui/screens/game_screen.gd` |
| `panel_fade` | `src/ui/map/map_options_panel.gd`, `src/ui/screens/game_screen.gd` |
| `panel_slide` | `src/ui/map/map_options_panel.gd`, `src/ui/screens/game_screen.gd` |
| `pause_change` | `src/ui/screens/game_screen.gd` |
| `selection_pulse` | `src/ui/map/world_map_view.gd` |
| `speed_change` | `src/ui/screens/game_screen.gd` |

## Ambient ocean motion

The sea drifts very slowly — a few pixels of gradient over half a second — while
the campaign clock is running. It is off when the clock is paused, off in reduced
map detail, and off under reduced motion, so a still screen costs nothing: the map
only redraws when something actually changed.

## What is not animated

Loading, saving, autosaving and the simulation itself never animate: they are
work, not presentation, and pretending otherwise would hide their real cost. The
developer overlay reports the truth instead.

## Regenerating

```bash
python3 tools/report_animations.py            # rewrite this file
python3 tools/report_animations.py --check    # fail when it is stale
```
