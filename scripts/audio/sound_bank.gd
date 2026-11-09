class_name SoundBank
extends Resource
## All game sounds by id (res://data/sound_bank.tres). Replace any stream in the Inspector
## with real audio later — code only ever asks for ids like "hit" or "battle".

## Short effects: "click", "hit", "crit", "heal", ...
@export var sfx: Dictionary = {}
## Looping tracks: "castle", "battle", "boss".
@export var music: Dictionary = {}
## Per-sfx volume offset in dB (optional).
@export var sfx_db: Dictionary = {}


func get_sfx(id: String) -> AudioStream:
	return sfx.get(id)


func get_music(id: String) -> AudioStream:
	return music.get(id)
