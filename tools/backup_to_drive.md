# Putting a code snapshot in Google Drive

A written procedure, so that anybody — the owner, a future contributor, or an assistant with
no memory of this milestone — can make the next backup without guessing. It is deliberately a
**manual** procedure: no script in this repository talks to Google Drive, keeps a token, or
runs on a schedule, because a backup tool that holds credentials is a bigger risk than the
thing it protects.

Drive is the owner's private convenience copy. **The repository is the source of truth.**

## 1. Where backups live

```
World Dominion/                 (the owner's folder)
└── Game Codes/
    ├── INDEX.md                (what each folder is, and how to restore it)
    ├── latest/                 (the newest snapshot; replaced each time)
    ├── M01 - 2026-11-04 - ef112b4/
    │   ├── m01-2026-11-04-ef112b4.zip
    │   └── README.md
    ├── M02 - …/
    └── … M09 - 2026-11-07 - b67df8f/
```

Nothing outside `Game Codes/` is touched, ever. The folder name pattern is
`M<NN> - <merge date> - <7-character merge commit>`.

## 2. Before you start

1. The milestone is **merged** into `main`. A snapshot of an unmerged branch is a snapshot of
   something that may never exist; back up the merge commit instead.
2. `main`'s Validation run is green. A backup of a red build is still useful, but say so in
   the folder's README if you upload one.
3. `git fetch --tags` in a full clone (a shallow clone cannot archive an older commit).

## 3. Make the archive

For each milestone you are adding — normally just the one you just merged:

```bash
SHA=$(git rev-parse <merge-commit>)                  # e.g. b67df8f09c6388b1380d9b83957047a96fa17667
DATE=$(git show -s --format=%cd --date=format:%Y-%m-%d "$SHA")
NAME="m10-${DATE}-$(git rev-parse --short=7 "$SHA")"
git archive --format=zip -o "/tmp/${NAME}.zip" "$SHA"
```

* `git archive` writes the **tracked files at that commit**, not your working tree: a stray
  local edit cannot leak into a backup.
* It does not include `.git`, so there is no history in the zip. That is intended: the
  history is on GitHub, and the point of the snapshot is to survive a lost repository.
* It does not include ignored files (`data/source/`, build output). The datasets are
  reproducible from the pins recorded in `data/world/` and in `tools/`.

## 4. Scan it before it leaves the machine

The rule is absolute: **no secret is ever uploaded.** Scan the archive's file list, then the
archive's text:

```bash
unzip -l "/tmp/${NAME}.zip" \
  | grep -Ei '\.(env|jks|keystore|p12|pfx|pem|key)$|(^|/)(id_rsa|\.netrc|\.git-credentials|credentials|secrets?)(\.|/|$)'

git grep -In -E "BEGIN [A-Z ]*PRIVATE KEY|AIza[0-9A-Za-z_-]{35}|ghp_[0-9A-Za-z]{30}|sk-[A-Za-z0-9]{20}" "$SHA" -- .
```

Both commands must print nothing. If either prints something, **stop**: fix the repository
first, then start again. Never upload a file and "delete it later" — Drive keeps versions.

## 5. Write the folder README

Each snapshot folder gets a `README.md` in plain language (no jargon, short sentences) that
answers, for somebody who has never seen this project:

* what the snapshot is and which milestone it belongs to;
* the exact commit, date and zip name, and the zip's size;
* how to restore it: unzip, install Godot 4.6.3, **Import** `project.godot`, press **F5**;
* what is *not* inside (`.git`, `data/source/`) and why;
* that the GitHub repository remains the source of truth.

Keep it under a screenful. A backup nobody can restore is not a backup.

## 6. Upload, in this order

1. Create the folder `M<NN> - <date> - <short sha>` inside `Game Codes/`.
2. Upload the zip into it, keeping the file name from step 3.
3. Upload the `README.md` into the same folder.
4. Replace the contents of `latest/` with this snapshot (delete the old zip and README there
   **only** — never delete a milestone folder) and give the file the name
   `latest-<date>-<short sha>.zip`.
5. Update `Game Codes/INDEX.md`: add the row, fix the `latest` row, and keep the total size
   line correct.

## 7. What must never happen

* **Never delete or overwrite an older milestone folder.** A backup that can be replaced is
  not a backup. `latest/` is the single folder that is meant to be replaced.
* **Never upload anything from outside this repository.** No drafts, no screenshots, no
  reference material, no `.env` file, no keystore, no token.
* **Never put credentials in a script in this repository.** If automation is ever wanted, the
  authentication belongs to the machine, not to the project.
* **Never treat Drive as the source of truth.** If the two disagree, the repository wins and
  the backup is stale — replace it.

## 8. After a backup, say so

The milestone's final report carries a checklist item **"Drive backup updated"**, with the
folder names that were added and the sizes that were uploaded, so the owner can verify the
claim from the Drive side without opening the repository.
