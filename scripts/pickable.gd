class_name Pickable
extends Item

@export var item_name: String = "物品"
@export var pick_color: Color = Color(0.9, 0.7, 0.1, 1.0)

var _is_picked: bool = false


func _ready() -> void:
	super._ready()
	_color_model(pick_color, 0.85)


func _process(delta: float) -> void:
	super._process(delta)
	if _player_in_range and _prompt_label and _prompt_label.visible and Input.is_action_just_pressed("interact"):
		_pick_up()


func _pick_up() -> void:
	if _player and _player.has_method("add_skill_xp"):
		_player.add_skill_xp("技能一", 100)
		_player.add_skill_xp("技能二", 50)
	print("[Pickable] 拾取: ", item_name)
