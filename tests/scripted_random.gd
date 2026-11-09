extends RandomSource
## Returns a fixed sequence of values (repeating the last) for deterministic tests.
## Note: roll(0) and roll(>=1) consume no value.

var _values: Array[float] = []
var _index := 0


func _init(values: Array[float] = [0.99]) -> void:
	_values = values if not values.is_empty() else [0.5]


func value() -> float:
	var v := _values[mini(_index, _values.size() - 1)]
	_index += 1
	return v
