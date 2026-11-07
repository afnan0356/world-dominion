# Screen map

**What this page is.** Every screen the game has and every screen it plans to have, where a
player reaches it from, which milestone builds it, and what data it needs. It exists so that a
later milestone cannot add a screen nobody can reach, and so the answer to "where would that
live?" is written down before the screen is built.

**How to read it.** *Built* means the screen exists and a player can open it in this build.
*Planned* means it is designed in outline and nothing is drawn for it yet — the game does not
show a mock version of it. The milestone column names the milestone that will build it. Numbers
past Milestone 11 are **not** assigned in `ROADMAP.md`, so a future screen is named by its planned
milestone's theme ("Politics & economy") rather than by an invented number.

## 1. The game screen's zones

One screen carries the campaign. Everything else opens on top of it or leaves it.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  avatar  coins  gems  XP/level                          flag  ▸ country       │  top bar
├──────────────────────────────────────────────────────────────────────────────┤
│  population   area   GDP (as of year)   currency        ▸ figures strip       │
├────────────┬────────────────────────────────────────────┬────────────────────┤
│ messages   │                                            │  news              │
│  (unread)  │                 the map                    │  events            │
│            │                                            │  (diplomats: later)│
│ alerts     │                                            │                    │
│  (later)   │                                            │                    │
├────────────┴─────────────────────────────────────────────────────────────────┤
│ menu  research▸  missions▸   [Country][Economy][Government][Diplomacy]        │
│                              [Military][Research][World]     speed  date  ▸   │
└──────────────────────────────────────────────────────────────────────────────┘
```

The zone on the left opens the left panel, the zone on the right the right panel, and the
category bar opens the panel for the chosen category. A panel is a `ModalPanel`
(`src/ui/components/modal_panel.gd`), so it traps focus, closes on Escape, and returns focus to
the control that opened it.

## 2. Screens that exist in this build

| Screen | Opened from | Milestone | Data it needs | State |
| --- | --- | --- | --- | --- |
| Loading | starting a campaign | M08 | the atlas and the chosen country's folder | **Built** |
| Terms and privacy | first run | M08 | `data/app_meta.json` | **Built** |
| Profile creation | first run | M08 | the profile file | **Built** |
| Main menu | launch | M02, polished M09 | the profile and the world list | **Built** |
| Country picker | Play | M08 | `data/world/` country records, statistics, currency | **Built** |
| Campaign setup | Play → choose a world | M02 | scenario definitions | **Built** |
| Game screen (the shell above) | after setup | M10 | the campaign, the profile, the event log | **Built** |
| Country overview | top-right flag, or a country on the map | M10 | that country's folder, statistics and currency | **Built** |
| Country dossier | map selection | M04 | the country folder | **Built** |
| Country comparison | country overview → compare | M04 | two countries' statistics | **Built** |
| Messages | left rail | M10 | the campaign's event log | **Built** |
| News | right rail | M10 | the same event log, printed as a page | **Built** |
| Pause menu | bottom-left | M03 | nothing | **Built** |
| Tutorial | bottom-left, first run | M08 | `src/ui/tutorial/` steps | **Built** |
| Settings | pause menu | M09 | the settings file | **Built** |
| Profile | pause menu | M08 | the profile file, avatar index | **Built** |
| Worlds | main menu | M09 | the save directory | **Built** |
| Backup and restore | Worlds | M08 | save files, the backup bundle | **Built** |
| Integrity dialog | loading a damaged save | M08 | the save file and its checksum | **Built** |
| Help | pause menu | M09 | the string table | **Built** |
| Roadmap | Help | M09 | `ROADMAP.md` content, in the string table | **Built** |
| About and credits | pause menu | M01, icons M11 | `data/credits.json`, `data/app_meta.json` | **Built** |
| About the data | About | M04 | `data/world/` provenance notes | **Built** |
| Diagnostics | pause menu | M09 | the engine's own logs, no personal data | **Built** |
| What is new | Help | **M11** | the string table only | **Built in M11** |

## 3. Screens that are planned

None of these is drawn today. Each row says what data it needs first, because that is the real
reason it is not built: a screen without data would have to invent it.

| Screen | Opened from | Milestone | Data it needs first | State |
| --- | --- | --- | --- | --- |
| Economy: budget, income and expenses | category bar → Economy | Politics & economy | tax and spending rules, the country's real output — see `docs/DATA_CANDIDATES.md` | **Planned** |
| Buildings and power | category bar → Country → Buildings | Politics & economy | a building catalogue with sourced or labelled costs, a power balance | **Planned** |
| Government and elections | category bar → Government | Politics & economy | parties, seats, turnout, an election rule | **Planned** |
| Ministries and ministers | Government → Ministries | Politics & economy | ministry list, minister skills and loyalty rules | **Planned** |
| Society, ideology and religion | category bar → Government → Society | **Owner decision** (see `docs/FEATURE_INVENTORY.md` §6) | the owner's neutrality decision | **Planned** |
| Public ratings | Government → Approval | Politics & economy | a rating derived from recorded causes | **Planned** |
| Research tree | bottom-left, research | Politics & economy | a short, costed tree | **Planned** |
| Diplomacy: relations, embassies, actions | category bar → Diplomacy | Diplomacy & military | relations data or a stated derivation, an AI reason to refuse | **Planned** |
| Diplomats' movements | right rail | Diplomacy & military | the diplomacy system | **Planned** |
| Military: force structure | category bar → Military | Diplomacy & military | force data, a combat rule, the owner's decision on literal war | **Planned** |
| Intelligence: spies, saboteurs | Military → Intelligence | Diplomacy & military | the owner's decision on covert play | **Planned** |
| Coups and internal security | Military → Security | Diplomacy & military | the same decision | **Planned** |
| The United Nations | category bar → World → UN | Unscheduled | resolutions, votes, vetoes, bribery — and the owner's position on each | **Planned** |
| Rankings | category bar → World → Rankings | Politics & economy | one measure the game actually tracks, named on screen | **Planned** |
| Four victory paths | World → Victory | Unscheduled | each path's own system | **Planned** |
| Space programme | category bar → Research → Space | Unscheduled | a costed programme and the economy to pay for it | **Planned** |
| Missions | bottom-left | Unscheduled | rewards worth having | **Planned** |
| Alerts that interrupt | left rail | Unscheduled | a reason to interrupt, and a setting to turn it off | **Planned** |
| Store, gems, daily rewards | — | — | — | **Rejected** (`docs/FEATURE_INVENTORY.md` §4) |

## 4. Rules every screen follows

1. **Reachable or not built.** A screen a player cannot open from the map above does not ship. A
   test checks that Help and the Roadmap mention only screens that exist.
2. **640×360 is a supported size.** Landscape, small window, phone held sideways: every panel must
   fit without overlapping text or pushing a control off the edge. The layout tests measure it.
3. **Both themes, keyboard, reduced motion.** A screen is checked in the light and dark palettes,
   fully reachable by keyboard with a visible focus ring, and its animation removed when reduced
   motion is on.
4. **Search and filters.** Any list longer than about a dozen rows gets a search field and at
   least one filter.
5. **Real or visibly missing.** A screen prints *Not available* where data is missing and never
   substitutes a zero, an estimate or a dash that looks like one.
6. **The string table.** Player-facing text lives in `src/ui/strings.gd`, not in a scene file, so
   it can be translated later and so a test can find a hard-coded sentence.
