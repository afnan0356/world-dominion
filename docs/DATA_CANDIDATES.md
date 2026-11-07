# Data candidates

**What this page is.** A record of what the project looked for to feed the systems the brief
asks for (population, output, prices, work, government, money, resources), what it found, and
what it could actually verify **here, by downloading the source and reading the source's own
files**. It ends with a shortlist for Milestone 12.

Two rules govern every row below, and they are the reason the page is short:

1. **Facts come from the source's own files.** Where this page says "licence: CC BY 4.0", that
   sentence is in the repository's `README.md` or `LICENSE` at the pinned commit, and the file
   was read during this milestone. Nothing here is recalled from memory.
2. **`VERIFIED` means downloaded and inspected in this environment.** `NOT VERIFIED` means it
   was not — and no value from it may enter the game until it is. A candidate that cannot be
   reached is reported as unreachable, not substituted with a mirror nobody checked.

**No data was imported in this milestone.** `docs/DATA_CANDIDATES.md` and
`tools/check_data_candidates.py` exist so that Milestone 12 starts from evidence rather than
from optimism.

**Reachable hosts here:** `github.com`, `codeload.github.com`, `api.github.com`,
`registry.npmjs.org`, `pypi.org`, `files.pythonhosted.org`. Everything below is hosted there or
is unreachable, and that fact is stated per row rather than worked around.

---

## 1. What is already shipped (for reference)

| | |
| --- | --- |
| Dataset | Natural Earth 1:50m Cultural Vectors, Admin 0 Countries |
| Pinned | `ca96624a56bd078437bca8184e78163e5039ad19` (`nvkelso/natural-earth-vector`) |
| Licence | Public domain, per the dataset's own terms — see `THIRD_PARTY_LICENSES.md` |
| Gives | 242 records, ISO alpha-2/alpha-3, name and long name, sovereignty, `TYPE`, region and sub-region, capital and its point, the geometry, `POP_EST` (with `POP_YEAR`), `GDP_MD` (with `GDP_YEAR`) |
| Gaps | Nothing live: every figure is a single estimate for one year, and the file says so |

Used as the baseline (`CountryState`). Its two economic columns are **estimates the publisher
labels as estimates**, carried with their year, never adjusted by this project.

## 2. Candidates, in the order they matter

### 2.1 CIA World Factbook archive — government type, head of state, current-year economy

| | |
| --- | --- |
| Repository | `https://github.com/factbook/factbook.json` |
| Pinned | `144d6977b2b01ac1cbd220de754c0a005616760b` (2026-09-11) |
| Licence | **CC0 1.0 Universal**, stated in the repository's `LICENSE.md`, which was read here; the README also states the original publication is in the public domain |
| Status | **VERIFIED** — a country file was downloaded and its structure read |
| Notes | The README states the CIA **discontinued the World Factbook in February 2026**; this repository is an archive of it |

**Contents, as inspected.** One JSON file per country under continent folders
(`south-asia/bg.json`, …), with sections `Introduction`, `Geography`, `People and Society`,
`Environment`, `Government`, `Economy`, `Energy`, `Communications`, `Transportation`, `Military
and Security`, `Space`, `Terrorism`, `Transnational Issues`.

**Indicators that fill a gap here:**

| What the game needs | Where it is | How it is stored |
| --- | --- | --- |
| Government type | `Government → Government type` | free text, e.g. `"parliamentary republic"` |
| Head of state | `Government → Executive branch → chief of state` | free text **including a person's name and a date** |
| Head of government | `Government → Executive branch → head of government` | same |
| Inflation (consumer prices) | `Economy → Inflation rate (consumer prices)` | text with its own year inside |
| GDP growth rate | `Economy → Real GDP growth rate` | text with its own year inside |
| Unemployment rate | `Economy → Unemployment rate` | text with its own year inside |
| Industries, agricultural products | `Economy → Industries` | free text |
| Military expenditure and branches | `Military and Security` | text |

**Country identifier.** The file names are **FIPS-style two-letter codes** (`bg.json` is
Bangladesh), not ISO 3166. Joining to the game's stable ISO-based ids therefore needs an
explicit FIPS → ISO crosswalk (candidate 2.5 supplies one), and the join must be recorded per
record, not inferred from a name.

**Gaps and limits, stated plainly:**

* Every economic figure is **free text with the year inside the sentence**, not a number and a
  year in separate fields. Using it means parsing text, which this project will only do with a
  rule that is tested against every record and reports every failure.
* Heads of state and government are **named private individuals**. The neutrality rule says the
  game does not depict real people; a head-of-state field would have to be a role, or be left
  out (see `docs/FEATURE_INVENTORY.md` §6).
* The dataset is an **archive of a discontinued publication**. It will not be updated, so it is a
  snapshot, and the year of each figure is whatever the archive captured.

### 2.2 Our World in Data — energy, and a cross-check for population and GDP

| | |
| --- | --- |
| Repository | `https://github.com/owid/energy-data` |
| Pinned | `f8de88a4f6f9cab44f1cf606047cbd6c4414042c` (2026-10-01) |
| Licence | The repository's `README.md`, section *License*, states: "All visualizations, data, and code produced by Our World in Data are completely open access under the Creative Commons BY license" — i.e. **CC BY 4.0** for OWID's own work — and that third-party data keeps its original terms, with the original source indicated per column |
| Status | **VERIFIED** — the codebook was downloaded and read (131 columns) |
| Files | `owid-energy-data.csv` (9.2 MB), `owid-energy-codebook.csv` (45 KB), `README.md` |

**Contents, as inspected in the codebook.** Columns include `country`, `year`, `iso_code`
(ISO 3166-1 alpha-3), `population`, `gdp`, and per-fuel consumption, electricity generation and
share columns, each with its own `unit` and `source` in the codebook. Two examples read from the
codebook: `population` — "Population by country, available from 10,000 BCE to 2100, based on
data and estimates from different sources"; `gdp` — Maddison Project Database 2023, in
"international-$ in 2011 prices".

**Country identifier.** `iso_code` is ISO 3166-1 alpha-3, which matches the game's stable ids
directly for the records that have an ISO code. Rows also include **aggregates** (`World`,
continents, income groups), so a filter is needed: an aggregate must never be mistaken for a
country.

**Gaps and limits:**

* The README carries a **transition banner**: the way primary energy is measured has changed, the
  figures "are not directly comparable with previous releases", and the new files live on
  `catalog.ourworldindata.org`, which is **not reachable** from here. This repository's CSV is the
  legacy release.
* `gdp` is a historical Maddison series, **not** a current-year figure; it is a cross-check, not a
  replacement for the baseline's GDP.
* CC BY 4.0 requires attribution to OWID **and to each column's own source**, which the codebook
  gives. That attribution must appear in the game, not only in a document.

### 2.3 Our World in Data dataset archive — historical series, but no licence statement

| | |
| --- | --- |
| Repository | `https://github.com/owid/owid-datasets` |
| Pinned | `6155d4ca1ea14ef30e753010a25521eeb416e8a2` (2025-04-14) |
| Licence | **Not stated in the repository.** The `README.md` was read in full for licence wording and none exists; it says only that the repository "has not been update in some time" and **has been archived** |
| Status | **VERIFIED as to structure, BLOCKED as to licence** |
| Shape | 766 dataset folders, each with a `.csv`, a `README.md` and a `datapackage.json` |

**What was inspected.** Three datasets were opened, including their `datapackage.json`:
*Mineral production (BGS (2016))* (206 KB), *Reserves-Production Ratio - BP Statistics (2016)*,
and the folder listing for unemployment series. Each `datapackage.json` carries `name`, `title`,
`description`, `sources` (publisher, link, retrieved date, additional notes) and the CSV schema —
**but no licence field**, and the repository states no licence for the data.

**What it would have given:** mineral production by country and year, reserves-to-production
ratios by fuel, and WDI/ILOSTAT-derived series for unemployment and growth.

**Why it is blocked:** every dataset here is third-party data republished by OWID. Without a
licence statement in the repository, use requires verifying each upstream publisher's own terms
one dataset at a time. That is real work, and doing it for one dataset at a time is the only
honest route. **Nothing from this archive may be imported until that is done.**

**Also a mapping gap:** these CSVs identify countries by `Entity` **name**, not by an ISO code, so
a name-based join is required — and names are exactly what changes between releases.

### 2.4 Unicode CLDR — ISO 4217 currencies

| | |
| --- | --- |
| Repository | `https://github.com/unicode-org/cldr` |
| Pinned here | `f69257926c43f1cb22cf3fcd93e709a2ca994bb7` (2026-11-03) |
| Licence | `LICENSE` — "COPYRIGHT AND PERMISSION NOTICE, Copyright © 2001–2026 Unicode, Inc. … Unicode Technical Standard #35 …", i.e. the **Unicode License V3**, already credited in `THIRD_PARTY_LICENSES.md` |
| Status | **VERIFIED** (and already in use: `data/world/currency_crosswalk.json`) |
| Gives | territory → ISO 4217 code, display name and symbol, for 229 of the 242 records |
| Gaps | 13 records have **no ISO 3166-1 code of their own**, so they get no currency — correctly, as "Not available" |

### 2.5 `datasets/country-codes` — the FIPS/ISO/M49 join

| | |
| --- | --- |
| Repository | `https://github.com/datasets/country-codes` |
| Pinned | `2d84034a0cae19ea5444b78c2131304a5c7f4bb9` (2026-10-15) |
| Licence | **Mixed, and the repository says so itself.** Its *License* section places the maintainers' own work (scripts, selection and arrangement) under the **PDDL**; it labels the UN M49 columns, Statoids, SIX Group and ISO's own rights in the codes **"licence unclear"**; `ATTRIBUTION.txt` credits GeoNames (CC BY 4.0) and the Unicode CLDR (Unicode License v3), and the README credits Wikidata (CC0) |
| Status | **VERIFIED, usable only as a join table with its caveat recorded** |
| Gives | ISO alpha-2/alpha-3/numeric, M49, **FIPS**, ITU, IOC, FIFA, DS, WMO, GAUL, MARC, dial codes, capital, continent, TLD, languages, and ISO 4217 currency columns |
| Gaps | The very columns a FIPS join needs (FIPS, M49) come from Statoids/UN sources whose licence the repository describes as unclear; a project that ships them inherits that question |

**What it is good for here:** it is the only reachable, inspectable table that maps the
Factbook's FIPS keys to ISO codes. A crosswalk derived from it is a *mapping*, not a copy of the
data: 242 rows of "FIPS → ISO", each checkable against the Factbook's own file list. That use is
recorded here so the decision is visible.

### 2.6 `lukes/ISO-3166-Countries-with-Regional-Codes` — UN regions

| | |
| --- | --- |
| Repository | `https://github.com/lukes/ISO-3166-Countries-with-Regional-Codes` |
| Pinned | `145f1ad3caff212ed25f42b0ee2c8b92a75af895` (2024-06-29); `LAST_UPDATED.txt` says 2024-06-19 |
| Licence | `LICENSE.md`: **Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)** — read here |
| Status | **VERIFIED, and not needed** |
| Gives | ISO alpha-2/alpha-3, UN region, sub-region and intermediate region |
| Why not needed | The game already has region and sub-region from Natural Earth, and **share-alike** would attach a licence obligation to anything derived from this table for no gain |

---

## 3. What is still missing

| The game will need | What exists here | What is missing |
| --- | --- | --- |
| Population and GDP **growth series** | a single-year estimate in the baseline; a historical Maddison `gdp` series inside the energy CSV | a clean, licenced, current growth series. The Factbook has GDP growth as text with a year inside; the archive that would give a series has no stated licence |
| Inflation | Factbook free text with the year inside | a numeric series with its own licence statement |
| Unemployment | Factbook free text; ILOSTAT-derived series in the unlicensed archive | the same |
| Government type | Factbook `Government type`, free text, archived publication | a live, machine-readable source |
| Head of state / government | Factbook, as named individuals | **a decision**: the neutrality rule probably means roles, not people |
| Election results | — | **nothing reachable.** No verified source of seats, turnout or results |
| Resource **deposits, reserves, production and extraction capacity** as four separate concepts | mineral production (BGS, unlicensed archive); reserves-to-production ratios (BP 2016, same); energy production and consumption by fuel (OWID, CC BY 4.0) | three of the four concepts. Reserves and extraction capacity in a licenced, current dataset were **not found**; the four concepts must not be collapsed into one number to hide that |
| Electricity **capacity** (MW) by plant type | generation in TWh by fuel, per year, in the OWID CSV | installed capacity, which is what a hard electricity limit needs |
| ISO and regional metadata | already shipped, from Natural Earth | nothing |

## 4. Shortlist for Milestone 12

Ordered by what unblocks the most with the least licence risk:

1. **Factbook archive (CC0) for government type and current-year economy — text-parsed, with a
   documented rule and a per-record report.** CC0 is the cleanest licence available here, and
   the fields it adds are exactly what the politics and economy screens need first. The parsing
   rule is the work, and every failure must be reported, never guessed. The head-of-state field
   waits for the owner's neutrality decision.
2. **A FIPS → ISO join derived from `datasets/country-codes`, recorded as mapping rows**, so the
   Factbook can be attached to the 242 stable ids. The caveat about that table's mixed licences
   goes into `THIRD_PARTY_LICENSES.md` in the same commit.
3. **OWID energy (CC BY 4.0) for energy production, consumption and electricity generation by
   fuel**, with OWID and each column's own source credited on screen and in
   `THIRD_PARTY_LICENSES.md`, and the transition banner's incomparability noted in the data file
   itself. Population and Maddison `gdp` come along as a cross-check, never as a baseline.
4. **A licence audit of one OWID archive dataset** — the BP reserves-to-production ratio — to see
   whether per-dataset upstream verification is practical. If it is, reserves enter the game
   with their own licence record; if it is not, the resource system starts without reserves and
   says so.
5. **Do not use CC BY-SA sources** (2.6) and **do not use unlicensed archives** (2.3) until their
   terms are settled. Nothing in the build depends on them.

**What is still missing after the shortlist:** election results, installed electricity capacity,
and any live source for heads of state. Those three are reported as gaps rather than filled with
an estimate.

## 5. How the check works

`tools/check_data_candidates.py` downloads **only metadata** for each `VERIFIED` candidate — the
licence file, the README, or the `datapackage.json` — and checks that:

* the repository and the pinned commit still resolve;
* the licence file the table above names is still there;
* the dataset's own description still contains the words this page quotes.

It imports nothing, downloads no data file, and prints a table. It exits non-zero when a
candidate has moved, so a later milestone discovers a change here rather than in the middle of
an import. It is run in CI with `continue-on-error`, because a third-party repository being
unreachable must not be able to fail this project's own build; the log is the evidence.
