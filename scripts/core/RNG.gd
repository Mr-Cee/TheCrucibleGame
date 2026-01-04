extends Node
class_name RNGService

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

func randi_range(a:int, b:int) -> int:
	return _rng.randi_range(a, b)

func randf() -> float:
	return _rng.randf()

func weighted_pick(items:Array, weights:Array) -> int:
	# Returns index picked.
	var total := 0.0
	for w in weights:
		total += float(w)
	if total <= 0.0:
		return 0
	var roll := randf() * total
	var acc := 0.0
	for i in range(items.size()):
		acc += float(weights[i])
		if roll <= acc:
			return i
	return items.size() - 1
