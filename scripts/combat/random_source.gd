class_name RandomSource
extends RefCounted
## Randomness wrapper so combat can be made deterministic in tests (seed or scripted values).

var _rng := RandomNumberGenerator.new()

func _init(seed_value: int = 0) -> void:
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()

## Uniform float in [0, 1).
func value() -> float:
	return _rng.randf()

func roll(chance: float) -> bool:
	if chance <= 0.0:
		return false
	if chance >= 1.0:
		return true
	return value() < chance

func range_f(min_v: float, max_v: float) -> float:
	return min_v + (max_v - min_v) * value()
