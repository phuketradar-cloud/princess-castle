class_name EssenceDrop
extends Resource
## What a monster may drop when defeated: `chance` to get between min and max essences.

@export var element: CardTypes.Element = CardTypes.Element.FIRE
## If set, drops this material instead of the element essence (e.g. "dragon_scale").
@export var material: String = ""
@export_range(0.0, 1.0) var chance: float = 1.0
@export var min_amount: int = 1
@export var max_amount: int = 1


static func make(p_element: int, p_chance: float, p_min: int, p_max: int) -> EssenceDrop:
	var d := EssenceDrop.new()
	d.element = p_element
	d.chance = p_chance
	d.min_amount = p_min
	d.max_amount = p_max
	return d


static func make_material(key: String, p_chance: float, p_min: int, p_max: int) -> EssenceDrop:
	var d := make(0, p_chance, p_min, p_max)
	d.material = key
	return d


## Material key stored in Collection.materials.
func key() -> String:
	return material if material != "" else CardTypes.element_key(element)


## Returns the amount dropped (0 if the chance roll fails).
func roll(rng: RandomSource) -> int:
	if not rng.roll(chance):
		return 0
	var span := maxi(0, max_amount - min_amount)
	return min_amount + mini(span, int(rng.value() * (span + 1)))
