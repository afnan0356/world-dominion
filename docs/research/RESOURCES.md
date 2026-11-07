# Research note — resources, energy and industry

**Status of this note: research only. Nothing here is implemented, and no figure in it may be
used in the game.** There is no economy, no production, no trade and no resource system in this
build; see `ROADMAP.md`.

## The question

A campaign about leading a nation is thin without materials: what a country makes, what it
must import, what it can cut off. The question this note asks is narrower and more useful:
**could this project model resources without inventing numbers, and what would it need?**

## What the project already holds

`data/world/statistics.json` carries three figures per record — population, GDP and an area
derived from the outline — from Natural Earth's own estimates, each with the year the source
records it for. Everything about resources is outside that. Two consequences follow, and they
are the reason this note exists rather than a first draft of a resource system:

* Nothing in the current data says what any country produces, consumes or trades.
* Therefore any resource figure in a prototype would be invented. A resource model built on
  invented numbers would be a game about nothing, wearing this project's honesty.

## Candidate sources (none of them consulted here)

| Candidate | What it is usually good for | Status | What must be checked before use |
| --- | --- | --- | --- |
| USGS Mineral Commodity Summaries | annual production of mineral commodities by country | `UNVERIFIED` | licence and redistribution terms; whether the machine-readable tables cover every record in `data/world/countries.json`; which year each table refers to |
| UN Comtrade | import and export values by commodity and country | `UNVERIFIED` | whether the free tier is machine-readable without an account; the size of a full extract; whether licence terms allow redistribution inside a game |
| IEA statistics | energy production, consumption and trade | `UNVERIFIED` | access terms — much of the detailed data is licensed and not redistributable |
| FAOSTAT | crop and livestock production | `UNVERIFIED` | licence (the project would need written terms, not a habit); per-country coverage and units |
| World Bank WDI | energy indicators per country | `NOT AVAILABLE` in this environment — `api.worldbank.org` could not be reached when the statistics work was done (see `docs/DATA_SOURCES.md`) | whether it becomes reachable at all; and it is still only indicators, not a commodity trade network |

Nothing in that table is a recommendation. It is a list of things to check, written down so the
checking is not repeated from memory.

## What a resource model would actually need

Written as requirements, because requirements are testable and prose is not:

1. **A per-record production figure per commodity, with its year.** Not a share, not a rank:
   the source's own number, and the year it refers to.
2. **A trade flow, or an explicit absence.** If the game cannot state who sells what to whom,
   it must say "unknown" rather than assume self-sufficiency.
3. **A unit and a scale, recorded.** Tonnes, barrels, kWh — the source's unit, kept verbatim,
   exactly as `statistics.json` keeps `GDP_MD` with its scale.
4. **Coverage accounting.** Every record with no figure is listed with the reason, the way
   `docs/CURRENCY_REPORT.md` and `docs/STATISTICS_REPORT.md` do it.
5. **A refusal rule.** When the sources disagree by more than a documented margin, the game
   shows neither and says they disagree. Averaging two statistical agencies is a stance.

Requirement 5 is the one that makes a resource system expensive, and it is the one that would
decide whether this is worth building at all.

## What is not known here, and would settle it

* Whether any of the candidates above can be redistributed inside a game — **licence text, not
  a summary**, examined for each one.
* How many of the 242 records any one source covers. A source covering 60 countries would mean
  182 records saying "Not available", which may be the right answer and is certainly a design
  decision.
* Whether a defensible model needs trade flows at all, or whether production plus an explicit
  "rest of world" bucket is enough. That is a game-design question, and there is no data
  answer to it.

## Deliberately not written

No numbers. No rankings. No "roughly X% of world production" — every one of those would be a
memory of somebody else's table, which is exactly what `docs/DATA_SOURCES.md` forbids.
