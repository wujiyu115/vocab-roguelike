# scripts/ui/touch_controls.gd
extends CanvasLayer

signal move_to(pos: Vector2)
signal fire_drag(dir: Vector2)
signal dash_pressed
signal interact_pressed
signal pause_pressed

@onready var interact_btn: Button = $InteractButton
@onready var dash_btn: Button = $DashButton
@onready var pause_btn: Button = $PauseButton
@onready var aim_line: Line2D = $AimLine
@onready var touch_area: Control = $TouchArea

var dragging := false
var drag_start := Vector2.ZERO
var player: Node = null

func _ready():
	if not GameManager.is_mobile:
		visible = false
		set_process(false)
		return
	dash_btn.pressed.connect(func(): dash_pressed.emit())
	interact_btn.pressed.connect(func(): interact_pressed.emit())
	pause_btn.pressed.connect(func(): pause_pressed.emit())
	interact_btn.visible = false

func setup(p: Node) -> void:
	player = p

func _process(_delta: float) -> void:
	if player == null:
		return
	_update_interact_button()

func _update_interact_button() -> void:
	var show := false
	# Check nearby meaning tokens
	var meanings := get_tree().get_nodes_in_group("meaning_tokens")
	for token in meanings:
		if is_instance_valid(token) and player.position.distance_to(token.position) < player.pickup_range:
			show = true
			interact_btn.text = "拾取"
			break
	# Check nearby chests
	if not show:
		var chests := get_tree().get_nodes_in_group("chests")
		for chest in chests:
			if is_instance_valid(chest) and not chest.opened and player.position.distance_to(chest.position) < 70:
				show = true
				interact_btn.text = "开箱"
				break
	interact_btn.visible = show

func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.is_mobile:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			if player and player.held_meaning.length() > 0:
				dragging = true
				drag_start = event.position
				aim_line.visible = true
			else:
				var world_pos := _screen_to_world(event.position)
				move_to.emit(world_pos)
		else:
			if dragging:
				var drag_dir := (event.position - drag_start).normalized()
				if (event.position - drag_start).length() > 30:
					fire_drag.emit(drag_dir)
				dragging = false
				aim_line.visible = false

	if event is InputEventScreenDrag and dragging:
		aim_line.clear_points()
		aim_line.add_point(drag_start)
		aim_line.add_point(event.position)

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var viewport := get_viewport()
	var canvas_transform := viewport.get_canvas_transform()
	return canvas_transform.affine_inverse() * screen_pos
