# What is new

**What this page is.** The rules behind the **What is new** screen — where its words come from,
why every line carries a list of files, and what a maintainer has to do to add an entry. The
screen exists so that a player can find out what changed without reading a changelog written for
programmers, or the repository at all.

**Where it lives.**

| Piece | File |
| --- | --- |
| The screen | `src/ui/screens/whats_new/whats_new_screen.tscn`, `whats_new_screen.gd` |
| The content table | `src/ui/screens/whats_new/whats_new_items.gd` |
| The words | `src/ui/strings.gd`, keys under `whats_new.` |
| The test | `tests/suites/test_whats_new.gd` |
| The layout | [`docs/layout-diagrams/what-is-new.md`](layout-diagrams/what-is-new.md) |

**Where a player finds it.** Two places, both of them where somebody would look: the **main
menu → Library → What is new**, and the **pause menu of a running campaign**. A player who is
told "this build changed" should not have to quit to read what changed; the test opens both.

## 1. One card per change, and each card names its evidence

Every entry in `WhatsNewItems.RELEASES` is a title key, a body key and an `evidence` list of
repository paths. The test reads every path and fails when one is missing, so a note cannot
describe work that was reverted, a file that was renamed, or a feature that only nearly shipped.

That rule is the whole point of the screen. Release notes rot faster than any other page in a
project: they are written once, in a hurry, at the end. Making rot a test failure is the only
defence that does not depend on somebody remembering to reread them.

Two smaller rules follow from it:

* **At least two files per entry.** An entry that cites one file which every other entry also
  cites is not traceable to anything in particular.
* **The citation is printed.** The card shows the paths as a caption, not only in the table. A
  test compares the labels on screen with the table, because a citation the reader cannot see
  is not a citation.

## 2. It ends with what is not there

The last section is **Not in this build**. A notes page that lists only additions quietly turns
"in progress" into a claim nobody checked — and this build has no economy, no politics, no
diplomacy and no country AI. That section cites the same kind of evidence, so it is as checkable
as the rest.

It is deliberately **not** a list of dates or promises. `ROADMAP.md` owns those, and a second
list of them would be a second thing to keep true.

## 3. The version on the page is the running build's

The header prints the version from `application/config/version` in `project.godot`, which is the
same setting the main menu's version line and every save file read. No version number is typed
into the string table, so the page cannot claim a build the player is not running.

## 4. No motion

The page has no tweens, no staggered entrance and nothing that moves when it appears, so reduced
motion needs no special case: it is a list of cards in one reading column. Like the Roadmap, it
is the least designed screen on purpose.

## 5. Adding an entry

1. Add the words to `src/ui/strings.gd` under `whats_new.` — a title and a body.
2. Add the entry to `RELEASES` in `whats_new_items.gd` with the files that make the sentence
   true. Two at minimum, and they must be files a reader can open in the repository.
3. Run `godot --headless --path . res://tests/test_runner.tscn` (or let CI do it). The suite
   fails if a key is missing, a sentence is shorter than a token, or a cited path does not
   exist.

Nothing else needs editing: the screen draws whatever the table holds, in table order.
