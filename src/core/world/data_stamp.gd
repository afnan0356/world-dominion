class_name DataStamp
extends RefCounted
## A short, stable fingerprint of the static world data a save was made against.
##
## A save never contains map geometry. It contains this stamp plus stable country
## ids, and the game resolves those ids against the registry it ships with. That is
## what keeps a save small and what lets the world data be corrected without
## rewriting every save — but it also means the game must be able to say *which*
## data a save expects. This stamp is that answer, in a form a player can read and
## a developer can compare:
##
##   `ca96624a/242/99567/8f2c1d0a`
##
##   source commit (short) / countries / vertices / fingerprint of the id set
##
## The fingerprint covers the sorted list of stable ids, because that is the part
## a save actually depends on: geometry can be re-triangulated, but an id that
## disappears would break a save that references it.

const FINGERPRINT_LENGTH := 8


static func compute(atlas: WorldAtlas) -> Dictionary:
	if atlas == null or not atlas.is_ready():
		return {}
	var ids := atlas.registry.ids()
	ids.sort()
	var source: Variant = atlas.manifest.get("source")
	var commit := ""
	if source is Dictionary:
		commit = str((source as Dictionary).get("commit", ""))
	var vertex_count := 0
	var counts: Variant = atlas.manifest.get("counts")
	if counts is Dictionary:
		vertex_count = int((counts as Dictionary).get("vertices", 0))
	var fingerprint := "\n".join(ids).sha256_text().substr(0, FINGERPRINT_LENGTH)
	return {
		"source_commit": commit,
		"short_commit": commit.substr(0, 7),
		"countries": ids.size(),
		"vertices": vertex_count,
		"ids_fingerprint": fingerprint,
		"label": "%s/%d/%d/%s" % [commit.substr(0, 7), ids.size(), vertex_count, fingerprint],
	}


## True when two stamps describe the same id set. A different commit with the same
## ids is reported as a difference in the label but is not a reason to refuse a
## save: ids are what the save depends on.
static func ids_match(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("ids_fingerprint", "")) == str(b.get("ids_fingerprint", ""))


static func label(stamp: Dictionary) -> String:
	return str(stamp.get("label", "unknown"))
