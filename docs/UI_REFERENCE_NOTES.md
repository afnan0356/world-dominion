# UI reference notes

**Status: reference only. Nothing in this document is implemented as a copy, and no material
from the sources below is part of this repository.**

## 1. What this document is for

A record of what was looked at while designing the game screen's shell in Milestone 10, and —
just as important — what was **not** taken from it. Two questions a reader should be able to
answer after reading it:

* what did the reference material influence? **Layout and feature coverage only.**
* what is in the repository because of it? **Nothing.** No image, screenshot, icon, logo,
  font, sound, name, number, character, unit or sentence from any source is committed here,
  and none is planned to be.

The material lives in the project owner's private Google Drive, in the folder
*World Dominion reference*. It is not part of the game, is not redistributed with it, and is
not linked from it. This document describes it in the project's own words.

## 2. What was available, and what could actually be read

The folder holds four PDF files, named by the time they were captured:

| File | Size |
| --- | --- |
| `2026-11-07 15-14-35.pdf` | 88 183 735 bytes |
| `15-15-32.pdf` | 89 326 691 bytes |
| `15-16-03.pdf` | 84 432 785 bytes |
| `15-16-32.pdf` | 63 347 985 bytes |

**They could not be read in this environment.** The Drive connector's text extraction refuses
files above 25 MB, and every one of these is two to three times that. The attempt is recorded
here rather than hidden: `read_file_text` on the smallest of the four returned the size limit
and no text.

So this document does **not** describe their contents. It records:

* what the milestone asked the interface to cover, taken from the milestone instructions;
* which of those features this build can support with real data, and which cannot;
* the rules that decide what a screen may show, which do not depend on any reference at all.

If the owner wants notes specific to those files, the files need to be reduced below the
connector's limit (splitting a PDF into pages is enough) and the notes can be written then.
Inventing a description of a document nobody read would be worse than leaving this gap open.

## 3. What the reference was meant to inform, and what this build does with it

The milestone's own feature list is the brief. Each row states how the shell answers it, in
this build, with real data:

| Feature the brief asks for | Where it is in this build | Where its data comes from |
| --- | --- | --- |
| A fixed top bar with the player's identity | `src/ui/hud/game_hud.gd`, top zone | the profile file and the save's player country |
| Currencies in the top bar | same, wallet blocks | `GameWallet` (Gold Coins, Red Gems) |
| Level and experience | same, XP block | `PlayerProfile` and `Progression` |
| A national flag | same, flag button | the shipped flag crosswalk |
| Reference figures for the country | same, stats strip | `data/world/statistics.json` and `currency.json` |
| A messages rail with an unread count | same, left rail | the campaign's event log |
| A news rail | same, right rail | the same log, printed as a newspaper page |
| Menu and tutorial access | same, bottom-left | the existing pause menu and guide |
| A category bar across the game | same, bottom-centre | seven categories; one built, six planned |
| Clock speed and the in-game date | same, bottom-right | `GameClock` |
| A reusable panel and list | `src/ui/components/modal_panel.gd`, `record_list.gd` | no data of their own |

Six of the seven categories have no systems behind them, and the game says so in one
paragraph instead of drawing a mock screen. That is a deliberate refusal of the most common
thing a reference like this encourages: a screenshot-perfect interface with nothing behind it.

## 4. The rules that decide what a screen may show

These come from the project's own constraints, not from any reference:

1. **Real or visibly missing.** Every figure is read from a file the game ships or from the
   running campaign. A gap is printed as *Not available*; it is never filled with a plausible
   number, a dash that looks like a zero, or an empty cell a player could misread.
2. **Inspiration, not imitation.** Layout ideas are allowed; assets, wording, names, icons,
   typesetting, sound and character designs are not. Where an interface decision came from a
   general convention (a top bar, a left rail, a category bar), that is what it is: a
   convention, drawn with this project's own tokens.
3. **Both themes, every layout.** Nothing in the shell is designed for one theme or one
   screen size; the tests mount it at six sizes and both themes.
4. **Nothing that pretends.** A button that opens a screen with nothing in it is worse than a
   button that says the feature is planned.

## 5. What would change this document

* The owner supplying readable versions of the four files.
* A future milestone that implements one of the six planned categories: the row above would
  name the screen and the data source, and the reference would still not be copied.

Until then, this page is deliberately short: it can only be as long as what was actually
learned, and what was actually learned is the shape of the brief.
