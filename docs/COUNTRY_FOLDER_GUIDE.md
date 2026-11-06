# The country folders — a plain guide

Every country and territory in the game has **its own folder** in
`data/world/countries/`. The folder's name is the country's **stable id** — a short code
that never changes, because save files and every other data file refer to the country by it.

```
data/world/countries/
  BGD/            ← Bangladesh
  USA/            ← United States
  AFG/
  ...
  ZWE/            (242 folders in this version)
```

Why do it this way? Because one 100 KiB `countries.json` is easy for a program and hard for a
person. Split into folders, you can open one country, see exactly what the game knows about it,
see what is missing, and read where each value came from — without reading 242 records to find
one.

## What the country codes mean

Each folder's `identity.json` holds two codes and a status, and the status is the interesting part.

* **`iso-official`** — this is the record's own ISO 3166-1 code: two letters (`BD`) and three
  letters (`BGD`). Most records are this.
* **`user-assigned`** — the code is widely used but no one has officially assigned it. Kosovo is the
  one example: `XK` is what the world writes, and it is not an ISO code, so the game says so.
* **`none`** — the pinned dataset has no code of this record's own, and this project does not invent
  one. Five records are in this state, among them Somaliland and the Siachen Glacier. Their folders
  still exist, their maps are still drawn, and their READMEs say plainly that a code is missing.

One rule is worth knowing because it explains a deliberate gap: a territory is **never** given its
administering state's code. The dataset's own corrected field offers `AU`/`AUS` for the Indian Ocean
Territories and Ashmore and Cartier Islands; adopting it would give three records the same code and
would read as a sovereignty claim. Those two keep no code.

Why this matters beyond tidiness: codes are how a player searches, how a save's country is
identified, and how the game can say "this place has no ISO code" without pretending otherwise. If
you are reading a folder and wondering why a code is blank, the answer is in its README, in its
`code_status`, and in `docs/COUNTRY_CODES_AND_REGIONS.md` — not in a guess.

## What a folder contains

| File | Present? | What it is |
| --- | --- | --- |
| `identity.json` | always | Names, codes, region, the dataset's own `type`, its sovereignty field and any status note |
| `geometry.json` | always | That country's outline: its polygons, bounding box, the anchor point for its map label, and any repairs made while building it |
| `capital.json` | only when the dataset has a capital | Capital name and coordinates. Absent — not an empty file — when the source has none |
| `statistics.json` | only when the source gives at least one figure | Population and GDP from the pinned source, plus the area derived from the outline. Written by `tools/build_statistics.py`, not by the atlas build |
| `sources.json` | always | Which dataset, which commit, the licence, the attribution, when it was retrieved and how it was processed |
| `README.md` | always | A generated one-page summary: what is here, what is missing and why |

**All of these files are generated.** Editing them by hand does nothing lasting: CI rebuilds the
tree and the comparison fails. To change data you change the pipeline
(`tools/build_world_atlas.py` for identity/geometry/sources, `tools/build_statistics.py` for the
figures) and rebuild.

`statistics.json` is the one file the atlas build does not own. Rebuilding the atlas
**preserves** it rather than deleting it, and the README it writes mentions it; if the
source or the outline changed, `python3 tools/build_statistics.py --check` fails and asks
for the statistics step to be re-run. The order in `CONTRIBUTING.md` is: atlas, then
statistics, then the pack.

## A worked example: Bangladesh

`data/world/countries/BGD/identity.json`:

```json
{
  "schema": 1,
  "kind": "identity",
  "id": "BGD",
  "name": "Bangladesh",
  "name_long": "Bangladesh",
  "formal_name": "People's Republic of Bangladesh",
  "adm0_code": "BGD",
  "iso_a2": "BD",
  "iso_a3": "BGD",
  "region": "Asia",
  "subregion": "Southern Asia",
  "type": "Sovereign country",
  "sovereignty": "Bangladesh",
  "note": null,
  "filter_region": true
}
```

* `id` is the stable id. It equals the folder name, and a validator checks that it always does.
* `formal_name` and `adm0_code` are aliases: the first is the source's formal name, the second is
  Natural Earth's own admin-0 code. Both are used to build the search key, so a player typing
  "People's Republic of Bangladesh" still finds the country.
* `type` is the **source's** classification — the same field the starting-nation rule reads. This
  project does not reinterpret it.
* `note` is `null` here because the dataset records no note for Bangladesh. That is not an error,
  and it is not filled in with something invented.
* `filter_region` says whether the region filter lists this record. It is checked to be exactly
  "region is one of the six filter regions", so it cannot drift into a hand-set flag.

`data/world/countries/BGD/capital.json`:

```json
{
  "schema": 1,
  "kind": "capital",
  "id": "BGD",
  "name": "Dhaka",
  "point": [90.405, 23.725],
  "source_field": "ne_50m_populated_places_simple.feature where adm0cap = 1"
}
```

The name and the point come from the *same* source feature, so the map never shows a capital name
from one place and a pin from another.

`geometry.json` holds 7 polygons and 384 points for Bangladesh: the mainland plus islands. Read
`README.md` in the same folder for the human summary.

## A worked example: the United States

`data/world/countries/USA/`:

* `identity.json` — `name` "United States of America", `name_long` "United States",
  `iso_a2` `US`, `iso_a3` `USA`, region `North America`, subregion `Northern America`,
  source `type` `Country`, sovereignty field `United States of America`.
* `geometry.json` — **127 polygons, 5 749 points**. Alaska, Hawaii, the Aleutians and every small
  island are separate polygons, which is why the count is high. The bounding box spans
  `-178.195, 18.964` to `179.78, 71.408`: it crosses the antimeridian, so its west edge is a
  larger number than its east edge. The renderer handles that; nothing is moved to make it tidy.
* `capital.json` — `"Washington,  D.C."` at `[-77.01, 38.9]`. The **double space** is in the
  source. The project does not "fix" source spellings, because then the data would no longer
  match the thing it claims to be.

```text
data/world/countries/USA/
  identity.json     names, codes, region, source type, sovereignty
  geometry.json     127 polygons, 5 749 points, bbox, label anchor
  capital.json      Washington,  D.C.  [-77.01, 38.9]
  statistics.json   population and GDP with their years, area marked derived
  sources.json      Natural Earth 1:50m, pinned commit, public domain
  README.md         the one-page summary
```

## The runtime pack, and why there are two copies

The game does **not** read these folders at runtime. Next to them sit three compact files:

```
data/world/countries.json    ← generated from the folders
data/world/geometry.json     ← generated from the folders
data/world/statistics.json   ← generated from the folders (Milestone 05)
data/world/manifest.json     ← counts, provenance and the hashes of the files above
```

These are the **pack**. They are what the game loads, and they are small and fast on a phone.
The folders are the source of truth a person reads; the pack is derived from them by
`tools/build_country_pack.py`.

Three things keep the two in step:

1. `python3 tools/build_country_pack.py --check` rebuilds the pack from the folders in memory and
   fails if a single byte differs. CI runs it on every push.
2. `manifest.json` records the SHA-256 of the pack files it was built with, and a test in the
   game checks those hashes against the files the game actually loaded.
3. `tools/validate_country_folders.py` checks the tree itself: required files, orphan folders,
   duplicate ids, schema versions, sources, README freshness, and portable folder names.

A useful side effect: `countries.json` and `geometry.json` are **byte for byte what the previous
version of the game shipped**. Only `manifest.json` grew (it now records the folder layout and
the pack hashes), so saves made before the reorganisation still load — proven by a frozen save
fixture in `tests/fixtures/`.

## Folder and file names are safe everywhere

The game targets Windows, macOS, Linux and Android, so:

* a folder name is `A–Z`, `0–9` and `-` only, at most 32 characters, starting with a letter or digit;
* no reserved Windows names (`CON`, `PRN`, `AUX`, `NUL`, `COM1`…`LPT9`) — the validator refuses them;
* no two folders may differ only by case, because Windows and macOS would treat them as one;
* file names are fixed and lowercase: `identity.json`, `geometry.json`, `capital.json`,
  `sources.json`, `README.md`.

The validator and a test in the game both check these rules, and the validator's own self-test
builds deliberately broken trees (a missing file, an orphan folder, a case collision, a stale
README, an empty capital placeholder, a wrong schema version, a reserved name, a hand-set
`filter_region`, an unexpected file) to prove it catches them.

## How a future system adds a file

When a real, sourced system arrives — the first will be demographics, because it is the one with
usable public data — it adds **one file per country**, and only for countries where the source
actually has data:

```
data/world/countries/BGD/economy.json     ← only when sourced data exists for Bangladesh
```

Rules for such a file, so that the tree stays trustworthy:

1. **Its own schema version.** `{"schema": 1, "kind": "economy", "id": "BGD", ...}`. A changed
   shape means a new number and a migration, never a silent edit.
2. **Its own source block**, with dataset, repository, commit, licence, attribution and retrieval
   date — copied from `sources.json`'s shape, not from memory.
3. **Only real values.** A field the source does not cover is `null`, and the record's `README.md`
   says so. No estimates, no interpolated numbers, no "typical" values.
4. **Registered in the validator.** It gets an entry in the allowed-files list, a schema check and
   a README section, so it cannot drift either.
5. **A pack field of the same name**, added by `tools/build_country_pack.py`, so the game can show
   it.

Until then **no such file exists anywhere** — no empty placeholders, because an empty
`economy.json` would look like "we have economy data and it is zero".

## Nothing here ships to a phone twice

The pack is what an export should include; the folders are for people and for CI. When export
presets are added (a later milestone), they must exclude `data/world/countries/**` so the APK does
not carry ~7 MiB of duplicate text. That is recorded in [ROADMAP.md](../ROADMAP.md) as a
requirement of the export milestone, and no export exists yet.

## Where to look next

| Question | Answer |
| --- | --- |
| What is in each field, exactly? | [DATA_SCHEMA.md](DATA_SCHEMA.md) |
| Where does the data come from? | [DATA_SOURCES.md](DATA_SOURCES.md) |
| Which records are missing what? | [DATA_COMPLETENESS.md](DATA_COMPLETENESS.md) (generated) |
| What does a technical word mean? | [GLOSSARY.md](GLOSSARY.md) |
