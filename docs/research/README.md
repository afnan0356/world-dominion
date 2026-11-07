# Research notes — method, and what a status word means

A research note answers one question: *could this project model something, and what would it
have to know first?* It is not a design decision and it does not put a number into the game.
Nothing in this folder is implemented, and nothing in it may be cited by code until it has
become a data task with a downloaded, licensed file behind it.

## The three status words, and why they are the whole point

Every source a note names carries exactly one of these:

| Status | Means | What it requires |
| --- | --- | --- |
| `CONSULTED` | A file from it was actually downloaded and read in this repository's pipeline | URL, version or commit, licence and retrieval date, recorded next to the note |
| `UNVERIFIED` | It is a candidate nobody here has checked | It may be named, but **nothing** about its licence, coverage or contents may be asserted |
| `NOT AVAILABLE` | It was tried and could not be reached or read | The error, the date and what was attempted |

That table exists because the alternative is the failure this project is built to avoid:
a plausible-looking number with no file behind it. `CONSULTED` is the only status that ever
allows a figure to be used, and the figure then lives in `data/`, with its own source block,
not in a prose document.

## How a note becomes real work

1. A note proposes a question and lists candidate sources with their status.
2. Somebody checks one candidate and records what they found — including "it does not cover
   the records we have".
3. If a source survives, a data task is opened: download it, pin it, record licence and
   retrieval date, write a builder, write a crosswalk, write a validator, and report every
   unmatched record.
4. Only then does a screen show it, and only with the gap language the rest of the game uses.

Steps 3 and 4 are how `data/world/statistics.json` and the currency data were added. The same
route is the only one this project accepts.

## The notes

| Note | The question |
| --- | --- |
| [RESOURCES.md](RESOURCES.md) | Could the game model resources, energy and industry without inventing numbers? |
| [POLITICS.md](POLITICS.md) | Could it model a political system and international relations without taking a side? |

Both end in the same place: a list of what is **not known here**, and what would settle it.
