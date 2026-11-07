# Research note — political data and relations

**Status of this note: research only. Nothing here is implemented.** There is no political
system, no diplomacy, no military and no internal politics in this build; `ROADMAP.md` records
them as planned and `docs/OPEN_ENDED_DESIGN.md` sketches why they are not here yet.

## The question

A nation-scale game eventually needs to answer: who governs, who is allied with whom, and what
happens when that changes? The question this note asks is the one that has to be answered
before any code: **could this project model politics without taking a side?**

That is not a rhetorical question. The dataset this project already ships is itself political:
`docs/DISPUTED_TERRITORIES.md` lists every unit Natural Earth labels disputed, dependent or
indeterminate, and the project reproduces those labels **verbatim and takes no position**. A
political model has to inherit that discipline or contradict it.

## What the project already holds, and what it does not

* It holds names, codes, regions, a source `type` and a sovereignty field per record — the
  dataset's words, reproduced without interpretation.
* It holds nothing about governments, parties, leaders, alliances, treaties, armed forces or
  territorial claims. Every one of those would be a new, licensed source with a crosswalk.

## Candidate sources (none of them consulted here)

| Candidate | What it is usually good for | Status | What must be checked before use |
| --- | --- | --- | --- |
| V-Dem | measures of democracy and governance, with a published codebook | `UNVERIFIED` | licence and attribution terms; whether the indices can be shown without implying endorsement; how it codes the units this project treats as indeterminate |
| Polity | a long-running regime-type series | `UNVERIFIED` | coverage of the records in this atlas; whether the licence permits redistribution inside a game |
| SIPRI | military expenditure and arms transfers | `UNVERIFIED` | licence; whether transfers are per-pair or aggregated; the gap between "spent" and "can fight" |
| UCDP | organised violence events and conflict summaries | `UNVERIFIED` | licence; whether event data can be shown without making the game a horror generator |
| ACLED | conflict events | `UNVERIFIED` | access terms — historically restricted; redistribution inside a product is unlikely to be permitted |
| Freedom House reports | narrative assessments, published as documents | `UNVERIFIED` | whether anything machine-readable exists; a narrative report is not a dataset and cannot be the source of a number |
| UN treaty series / alliances lists | who has signed what | `UNVERIFIED` | whether it is usable as a file at all, and how a "treaty in force" would be dated |

The recurring problem is visible in that table: the sources that are easy to read are the ones
whose terms are least likely to allow redistribution, and the ones that allow redistribution
are the ones whose per-country coverage is thinnest.

## The hard questions this note cannot answer

Recorded here because they are the reason a political model is not in the build:

1. **Neutrality.** The project would have to show a regime's *own* description or a sourced
   index's number, and nothing else. It would have to be able to say "the source disagrees
   with another source" and show that, rather than picking.
2. **Sovereignty.** Relations are between entities, and the atlas deliberately does not decide
   what the entity is. A model that treats Palestine or Kosovo as a diplomatic actor has taken
   the position `docs/DISPUTED_TERRITORIES.md` refuses to take.
3. **The player's stake.** A political model that is accurate is often unplayable; one that is
   playable is often a caricature. `docs/OPEN_ENDED_DESIGN.md` puts the religion question the
   same way — *model it, or keep the game neutral?* — and leaves it **open**.
4. **Harm.** Data about violence and repression, turned into a game mechanic, is a design
   choice with a real cost. This note does not pretend that cost away; it records that no
   decision has been made.

## What would settle it

* Licence homework, per source: redistribution inside a game, in writing.
* A coverage report per candidate against the 242 records — the same document every data
  source in this project already has to produce.
* A written position from the owner on questions 1–4. Until there is one, the answer to
  "should the game model politics?" is **open**, and the build stays as it is: a map, a
  calendar, a save system, and no claim about anybody's politics.

## Deliberately not written

No leader lists, no alliance membership, no "this country is an X" sentence. Those are the
claims this project does not make without a downloaded file and a licence behind them.
