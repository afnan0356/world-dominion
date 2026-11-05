class_name DeterministicRng
extends RefCounted
## A small, seeded pseudo-random generator that behaves identically everywhere.
##
## Why not the engine's `RandomNumberGenerator`? Because a save, a test and a
## replay must agree on every platform, and this generator's output is defined
## entirely by 32-bit integer arithmetic that is specified here, in this file.
## It is SplitMix32: add a constant, scramble with shifts and multiplies, return
## the scrambled value. Every intermediate is masked to 32 bits, so no result can
## depend on how a platform treats 64-bit overflow.
##
## Rules:
##   * the same seed always produces the same sequence (tested);
##   * the state is one 32-bit integer and can be saved and restored exactly;
##   * `next_int(min, max)` uses rejection sampling, so every value in the range
##     is equally likely — no modulo bias;
##   * nothing here reads the clock, the frame count or the player's device.
##
## This is a *game* generator: fast, reproducible and small. It is not suitable
## for anything security-related, and nothing in this project uses it for that.

const MASK32 := 0xFFFFFFFF
## SplitMix32's increment: the 32-bit truncation of the golden-ratio constant.
const GOLDEN := 0x9E3779B9
const MULTIPLIER_A := 0x21F0AAAD
const MULTIPLIER_B := 0x735A2D97

var _state := 0


static func from_seed(seed_value: int) -> DeterministicRng:
	var rng := DeterministicRng.new()
	rng.set_state(seed_value)
	return rng


## Sets the state; any integer is accepted and folded into 32 bits.
func set_state(seed_value: int) -> void:
	_state = seed_value & MASK32


func get_state() -> int:
	return _state


func next_u32() -> int:
	_state = (_state + GOLDEN) & MASK32
	var z := _state
	z = ((z ^ (z >> 16)) * MULTIPLIER_A) & MASK32
	z = ((z ^ (z >> 15)) * MULTIPLIER_B) & MASK32
	return (z ^ (z >> 15)) & MASK32


## Uniform integer in `[minimum, maximum]` inclusive. Returns `minimum` when the
## range is empty or reversed, rather than a value outside it.
func next_int(minimum: int, maximum: int) -> int:
	if maximum <= minimum:
		return minimum
	var span := maximum - minimum + 1
	if span <= 0 or span > 0x100000000:
		return minimum
	# Rejection sampling: discard the values that would make the last bucket
	# short, so the distribution stays uniform instead of biased.
	var limit := 0x100000000 - (0x100000000 % span)
	while true:
		var value := next_u32()
		if value < limit:
			return minimum + (value % span)
	return minimum


## Uniform float in [0, 1). 32 bits of precision, which is plenty for a game and
## is exactly reproducible.
func next_float() -> float:
	return float(next_u32()) / 4294967296.0


## True with probability `probability` (clamped to [0, 1]).
func chance(probability: float) -> bool:
	if probability <= 0.0:
		return false
	if probability >= 1.0:
		return true
	return next_float() < probability


## Picks one element, or null for an empty array. Never mutates the array.
func pick(options: Array) -> Variant:
	if options.is_empty():
		return null
	return options[next_int(0, options.size() - 1)]


## Fisher-Yates on a copy; the input array is untouched.
func shuffled(values: Array) -> Array:
	var out := values.duplicate()
	for index in range(out.size() - 1, 0, -1):
		var swap := next_int(0, index)
		var hold: Variant = out[index]
		out[index] = out[swap]
		out[swap] = hold
	return out


## How many draws this generator has made is not tracked on purpose: a counter
## would be state that a save could disagree with, and the state itself already
## determines the next draw.
