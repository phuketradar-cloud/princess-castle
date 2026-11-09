class_name CardTypes
## Card categories and essence elements.

enum Category { ATTACK, CONTROL, SUPPORT, SPECIAL }

## Elements double as the 5 Essence materials dropped by monsters.
enum Element { FIRE, ICE, SHADOW, LIGHT, DRAGON }

const CATEGORY_NAMES := ["ATTACK", "CONTROL", "SUPPORT", "SPECIAL"]
const CATEGORY_COLORS := [Color8(200, 60, 70), Color8(70, 140, 220), Color8(70, 180, 110), Color8(200, 140, 40)]
const ELEMENT_NAMES := ["Fire", "Ice", "Shadow", "Light", "Dragon"]
const ELEMENT_KEYS := ["fire", "ice", "shadow", "light", "dragon"]
const ELEMENT_COLORS := [Color8(255, 120, 50), Color8(120, 210, 255), Color8(160, 90, 230), Color8(255, 235, 140), Color8(220, 60, 60)]


static func category_name(c: int) -> String:
	return CATEGORY_NAMES[c]

static func category_color(c: int) -> Color:
	return CATEGORY_COLORS[c]

static func element_name(e: int) -> String:
	return ELEMENT_NAMES[e] + " Essence"

static func element_key(e: int) -> String:
	return ELEMENT_KEYS[e]

static func element_from_key(key: String) -> int:
	return ELEMENT_KEYS.find(key)

static func element_color(e: int) -> Color:
	return ELEMENT_COLORS[e]
