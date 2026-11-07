# Control sizes

**Generated from the source by `tools/control_size_report.py`. Do not edit by hand.**

Every control the player taps should be at least **48 px** tall — the same number as `DesignTokens.TOUCH_TARGET_MIN`, which is the size a finger needs. This page lists what the code actually asks for.

**What is measured:** the minimum height declared in the source, read from the files. This is not a rendered measurement: it is the number the layout engine is told to honour, which is the number a code review can check. A rendered measurement needs a running engine, and this project does not present a computed table as a screenshot of the game.

## Declaration with a reason to be smaller

| Location | Earlier size | Now | Why |
| --- | ---: | ---: | --- |
| `DesignTokens.CONTROL_HEIGHT` | 40 | 48 | Raised in Milestone 05. This is the height of buttons, fields and rows across every screen. |
| `CountrySearch.FIELD_HEIGHT` | 44 | 48 | Raised with it; the compact layout uses 44, below. |
| `RegionFilter.CHIP_HEIGHT` | 40 | 48 | Raised with it; the compact layout uses 32, below. |
| `DesignTokens.CONTROL_HEIGHT_COMPACT` | new | 40 | The bar controls on a window shorter than 460 px. Raising the target took 8 px from the map at 640×360, which the game-shell layout test refused (the map dropped to 50 px tall). A 40 px control is still a finger target, and the map keeps its height. Measured by `tests/suites/test_game_shell.gd` at every reference size. |

## Still below the target, on purpose

| Where | Height | Reason |
| --- | ---: | --- |
| `src/ui/components/country_search.gd:114` (line 114) | 44 px | compact layout only; the search field shares a row with the map, and 44 px still clears the 40 px the layout was designed around |
| `src/ui/components/region_filter.gd:63` (line 63) | 32 px | compact layout only (360 px tall landscape phone); the row scrolls horizontally, so a 48 px chip would hide the map |
| `src/ui/components/region_filter.gd:115` (line 115) | 32 px | compact layout only (360 px tall landscape phone); the row scrolls horizontally, so a 48 px chip would hide the map |
| `src/ui/theme/design_tokens.gd:CONTROL_HEIGHT_COMPACT` (line 71) | 40 px | short windows only (under 460 px tall); at 640×360 the buttons are 40 px so the map keeps more than the 50 px it had before the target was raised |

The compact-layout sizes are the only exceptions: at 640×360 the screen is 360 px tall in total, so a full-height control row would leave no map. Those sizes are still at least 32 px, which keeps them tappable and keeps every screen inside its layout at that size.

## Every declared height in the source

| Where | Height | Meets the target |
| --- | ---: | --- |
| `src/ui/components/avatar_glyph.gd:14` (line 14) | 48 px | yes |
| `src/ui/components/country_search.gd:114` (line 114) | 44 px | no — see above |
| `src/ui/components/country_search.gd:FIELD_HEIGHT` (line 20) | 48 px | yes |
| `src/ui/components/region_filter.gd:115` (line 115) | 32 px | no — see above |
| `src/ui/components/region_filter.gd:63` (line 63) | 32 px | no — see above |
| `src/ui/components/region_filter.gd:CHIP_HEIGHT` (line 14) | 48 px | yes |
| `src/ui/map/map_controls.gd:BUTTON_SIZE` (line 18) | 48 px | yes |
| `src/ui/screens/first_run/first_run_screen.gd:255` (line 255) | 56 px | yes |
| `src/ui/screens/profile/profile_screen.gd:160` (line 160) | 96 px | yes |
| `src/ui/theme/design_tokens.gd:CONTROL_HEIGHT` (line 66) | 48 px | yes |
| `src/ui/theme/design_tokens.gd:CONTROL_HEIGHT_COMPACT` (line 71) | 40 px | no — see above |
| `src/ui/theme/design_tokens.gd:NAV_ROW_HEIGHT` (line 61) | 56 px | yes |
| `src/ui/theme/design_tokens.gd:NAV_ROW_HEIGHT_COMPACT` (line 62) | 52 px | yes |
