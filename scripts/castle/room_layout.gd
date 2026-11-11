class_name RoomLayout
extends Resource
## Where things go in one wing's room (data in princess_roster.tres > room_layouts).
## All positions are on the 1920x1080 screen; furniture positions are the bottom-centre
## (where the piece touches the floor). Rooms without a layout use the controller defaults.

@export var wing: CastleTypes.Wing = CastleTypes.Wing.SWORD
## Drawn to cover the whole screen (keeps aspect ratio, centred).
@export var background: Texture2D
## CastleTypes.FurnitureSlot -> Vector2
@export var slot_positions: Dictionary = {}
## CastleTypes.FurnitureSlot -> float. Depth: pieces further back are a bit smaller.
@export var slot_depth_scale: Dictionary = {}
## Where she stands to look out of the window.
@export var window_spot := Vector2(640, 800)
## Default standing spot.
@export var stand_spot := Vector2(960, 990)
## Optional: CastleTypes.Activity -> Vector2 offset from the activity's furniture slot,
## overriding the controller defaults (tuned per background / furniture art).
@export var spot_offsets: Dictionary = {}
