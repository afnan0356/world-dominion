class_name RandomStreams
extends RefCounted
## Named random streams derived from one campaign seed.
##
## The rule that makes this worth its own class: **each future system gets its own
## stream**. If the economy draws numbers and politics also draws numbers, they
## must not share a sequence, because adding one system would then shift every
## number the other system sees and invalidate every existing save. With named
## streams, the economy's sequence depends only on the campaign seed and the
## stream name — never on what other systems did.
##
## Stream names are hashed with FNV-1a into a 32-bit seed, mixed with the campaign
## seed. The mapping is documented, deterministic and tested, so "economy" means
## the same stream on every device and in every version that keeps this rule.

const FNV_OFFSET := 0x811C9DC5
const FNV_PRIME := 0x01000193
const MASK32 := 0xFFFFFFFF
## An odd mixing constant; odd so that the mapping from names to seeds has no
## collision for the small set of names this game uses.
const GOLDEN_ODD := 0x9E3779B1

var _seed := 0
var _streams: Dictionary = {}


static func from_seed(seed_value: int) -> RandomStreams:
	var streams := RandomStreams.new()
	streams.set_seed(seed_value)
	return streams


func set_seed(seed_value: int) -> void:
	_seed = seed_value & MASK32
	_streams.clear()


func seed_value() -> int:
	return _seed


## The 32-bit state a named stream starts from. Exposed so the derivation can be
## asserted directly in tests, and so a future tool can explain a saved value.
func stream_seed(name: String) -> int:
	var hashed := FNV_OFFSET
	for index in name.length():
		hashed = ((hashed ^ name.unicode_at(index)) * FNV_PRIME) & MASK32
	# Mix with the campaign seed. Multiplying by an odd constant and xor keeps
	# every seed pair distinct for the names this game uses.
	return ((hashed ^ _seed) * GOLDEN_ODD) & MASK32


## The generator for `name`, created on first use and reused afterwards.
func stream(name: String) -> DeterministicRng:
	if _streams.has(name):
		return _streams[name] as DeterministicRng
	var rng := DeterministicRng.from_seed(stream_seed(name))
	_streams[name] = rng
	return rng


func has_stream(name: String) -> bool:
	return _streams.has(name)


## States of every stream created so far. Saved with the campaign so a reload
## continues exactly where it stopped, even mid-sequence.
func to_dict() -> Dictionary:
	var out := {}
	for name: String in _streams:
		out[name] = (_streams[name] as DeterministicRng).get_state()
	return out


## Restores saved states. Streams named in the save but never used before are
## created with their saved state; streams not in the save keep their derived
## seed. `issues` collects anything that had to be rejected.
func restore(data: Dictionary, issues: Array = []) -> void:
	for name: Variant in data:
		var key := str(name)
		var value: Variant = data[name]
		if not value is int:
			issues.append("random stream '%s' is not an integer; using its derived seed" % key)
			continue
		var rng := stream(key)
		rng.set_state(int(value))
