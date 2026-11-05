# Disputed, uncertain and dependent territories

## What this page is for

WORLD DOMINION shows the world exactly as its map data describes it. The map data is a public-domain dataset called **Natural Earth** (1:50m scale, pinned to one commit — see [DATA_SOURCES.md](DATA_SOURCES.md)). That dataset labels every unit with a `type`, such as `Sovereign country`, `Dependency`, `Disputed` or `Indeterminate`.

This project copies those labels and that geometry **without editing them**. It does not decide where a border should be, and it does not take a side in any sovereignty dispute.

Two plain-English consequences:

1. **This is one dataset's convention.** Another atlas, another government or another organisation would draw some of these lines and label some of these units differently. Nothing here is an official position of the project, its owner or its contributors on any border or sovereignty question.
2. **Changing it is a data decision, not a code decision.** If the owner later adopts a different policy, the change belongs in the data pipeline and in this document — not in `if country == …` code. There is no special-case code for any individual place.

The game also uses these labels for one practical rule: which records a player may start a campaign as. That rule is separate, explicit and data-driven — see [START_NATIONS.md](START_NATIONS.md). It is a default for review, not a judgement.

## Every record the source marks as uncertain or dependent

`type` is copied verbatim from the dataset. `id` is the stable identifier used everywhere in the game.

### `Disputed` — 4 record(s)

| Stable ID | Name | Source type (verbatim) | Region |
| --- | --- | --- | --- |
| `IOT` | Br. Indian Ocean Ter. | `Disputed` | Seven seas (open ocean) |
| `FLK` | Falkland Is. | `Disputed` | South America |
| `ISR` | Israel | `Disputed` | Asia |
| `KOS` | Kosovo | `Disputed` | Europe |

### `Indeterminate` — 4 record(s)

| Stable ID | Name | Source type (verbatim) | Region |
| --- | --- | --- | --- |
| `ATA` | Antarctica | `Indeterminate` | Antarctica |
| `PSE` | Palestine | `Indeterminate` | Asia |
| `KAS` | Siachen Glacier | `Indeterminate` | Asia |
| `ESH` | W. Sahara | `Indeterminate` | Africa |

### `Sovereignty` — 2 record(s)

| Stable ID | Name | Source type (verbatim) | Region |
| --- | --- | --- | --- |
| `CUB` | Cuba | `Sovereignty` | North America |
| `KAZ` | Kazakhstan | `Sovereignty` | Asia |

### `Dependency` — 28 record(s)

| Stable ID | Name | Source type (verbatim) | Region |
| --- | --- | --- | --- |
| `ASM` | American Samoa | `Dependency` | Oceania |
| `AIA` | Anguilla | `Dependency` | North America |
| `ATC` | Ashmore and Cartier Is. | `Dependency` | Oceania |
| `BMU` | Bermuda | `Dependency` | North America |
| `VGB` | British Virgin Is. | `Dependency` | North America |
| `CYM` | Cayman Is. | `Dependency` | North America |
| `COK` | Cook Is. | `Dependency` | Oceania |
| `FRO` | Faeroe Is. | `Dependency` | Europe |
| `PYF` | Fr. Polynesia | `Dependency` | Oceania |
| `ATF` | Fr. S. Antarctic Lands | `Dependency` | Seven seas (open ocean) |
| `GUM` | Guam | `Dependency` | Oceania |
| `HMD` | Heard I. and McDonald Is. | `Dependency` | Seven seas (open ocean) |
| `IOA` | Indian Ocean Ter. | `Dependency` | Asia |
| `MSR` | Montserrat | `Dependency` | North America |
| `MNP` | N. Mariana Is. | `Dependency` | Oceania |
| `NCL` | New Caledonia | `Dependency` | Oceania |
| `NIU` | Niue | `Dependency` | Oceania |
| `NFK` | Norfolk Island | `Dependency` | Oceania |
| `PCN` | Pitcairn Is. | `Dependency` | Oceania |
| `PRI` | Puerto Rico | `Dependency` | North America |
| `SGS` | S. Geo. and the Is. | `Dependency` | Seven seas (open ocean) |
| `SHN` | Saint Helena | `Dependency` | Seven seas (open ocean) |
| `BLM` | St-Barthélemy | `Dependency` | North America |
| `MAF` | St-Martin | `Dependency` | North America |
| `SPM` | St. Pierre and Miquelon | `Dependency` | North America |
| `TCA` | Turks and Caicos Is. | `Dependency` | North America |
| `VIR` | U.S. Virgin Is. | `Dependency` | North America |
| `WLF` | Wallis and Futuna Is. | `Dependency` | Oceania |

## How these records are drawn and handled

* Their geometry is drawn exactly as the dataset provides it. No record is merged into a neighbour, split, renamed, hidden or silently reclassified.
* The dossier shows the source's `type`, and for records the source marks `Disputed` or `Indeterminate` it adds one neutral sentence: *Status and boundaries follow the pinned Natural Earth dataset. That is this dataset's convention, not an official position of this project on any sovereignty or boundary question.*
* They can be selected on the map, searched, filtered and read in the dossier.
* Starting a campaign as one of them is governed by the same data-driven rule as everything else ([START_NATIONS.md](START_NATIONS.md)). That rule lists `type` values, not places.

## All classification values in this dataset

| Source `type` | Records |
| --- | --- |
| `Sovereign country` | 185 |
| `Dependency` | 28 |
| `Country` | 19 |
| `Disputed` | 4 |
| `Indeterminate` | 4 |
| `Sovereignty` | 2 |

## Keeping this page honest

```bash
python3 tools/report_policies.py          # regenerate this file and START_NATIONS.md
python3 tools/report_policies.py --check  # CI: fail when either file is stale
```
