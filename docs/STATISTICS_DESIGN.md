# Country statistics — design and scope

**Status: SHIPPED IN PART, PLANNED IN PART.** Milestone 05 ships the figures, their
provenance and two read-only screens. Everything that would *use* the figures in a
simulation is **PLANNED** and is described here so the boundary is on paper before anyone
builds it.

## What a player sees today

* The dossier has a **Key figures** group: population, GDP and area, each with the year
  its source records it for, and a line naming the source.
* The dossier has a **Compare this country** button. It opens a read-only comparison of up
  to three countries with one figure per row.
* **About the data** lists the statistics dataset, its version, the retrieval date, the
  licence, the attribution and how many records carry each figure.
* Every screen that shows a figure also carries the sentence *"Baseline reference data for
  the 2026 scenario start, not live."*

Nothing on those screens changes while the game runs. Nothing on them is ranked, scored or
sorted by value.

## The three figures

| Figure | Unit | Where the number comes from | Derived? |
| --- | --- | --- | --- |
| Population | people | the source's `POP_EST`, with the source's `POP_YEAR` | no |
| GDP | US dollars | the source's `GDP_MD` × 1 000 000 (millions → dollars), with `GDP_YEAR` | no |
| Area | square kilometres | computed from **this project's** simplified outline | yes |

Area is the odd one out and is labelled `derived` everywhere it appears, because it is not
a source statistic: it is the spherical area of the outline this build draws, which is a
1:50 m generalisation. It is close to official land-area figures for compact countries and
noticeably below them for countries with long, broken coastlines. It is useful for a
side-by-side comparison and it is not an official figure.

There is **one primary source** for population and GDP, and it is never mixed with
another. The source, its pin, its licence and every rejected value are recorded in
[`STATISTICS_REPORT.md`](STATISTICS_REPORT.md).

## Why the numbers are what they are

* **No arithmetic on the way in.** A value that is fractional, negative, missing, text or
  out of range is *rejected*, not rounded. The build records why, and the game shows
  "Not available". Two records lose a figure this way (a fractional population, and a
  `-99` GDP sentinel). A rejected value is never borrowed from a parent country.
* **A zero is a value.** Two uninhabited territories genuinely have a population of 0, and
  their files say `0`. The game distinguishes `0` from "missing" everywhere.
* **The join is a code, never a name.** `data/world/statistics_crosswalk.json` maps every
  registry ID to the source's own `ADM0_A3`, and records the source's name for each so a
  human can check it. Four records differ (`PSE→PSX`, `SSD→SDS`, `ESH→SAH`, `ALA→ALD`).
* **No sovereignty decision.** A territory gets a figure only when the source gives a row
  for that exact code. Nothing is summed into a parent, and nothing is split out of one.
* **One file per record that has data.** A record with no usable value gets no file at
  all, rather than a file full of empty fields.

## What is not built, and will not be without a milestone

These are **PLANNED**, and deliberately absent from this milestone:

* population in `WorldState`, growth, migration, or anything that changes over time;
* GDP used by an economy, trade, tax or production system;
* inflation, GDP per capita as a gameplay figure, or any projection;
* statistics affecting eligibility, borders, diplomacy, military strength or scoring;
* live data: there is no network access at runtime, by design.

The figures are **input to nothing**. A test in `tests/suites/test_statistics.gd` walks the
simulation and save code and fails if either mentions statistics at all. When a later
milestone does load them, that test is the one to change — deliberately, in a commit that
says so.

## For the next person

* `data/world/countries/<ID>/statistics.json` — one record's figures, with the source block.
* `data/world/statistics.json` — the same figures for the whole world, read by the game.
* `data/world/statistics_crosswalk.json` — the join, and the only place a code may differ.
* `tools/build_statistics.py` — the builder, the rejection rules and the report.
* `tools/validate_statistics.py` — the checks CI runs on the result.
* [`STATISTICS_REPORT.md`](STATISTICS_REPORT.md) — source, coverage and every rejection.

Loading a figure into a simulation is a design decision, not a data change: it needs a
milestone, a save migration and a reason a player can see.
