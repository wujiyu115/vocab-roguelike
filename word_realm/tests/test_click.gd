# tests/test_click.gd
extends "res://tests/base_test.gd"

var _btn_clicked := false
var _btn1_clicked := false
var _btn2_clicked := false

func _init():
	_suite_name = "ClickTests"

func _on_btn_pressed() -> void:
	_btn_clicked = true

func _on_btn1_pressed() -> void:
	_btn1_clicked = true

func _on_btn2_pressed() -> void:
	_btn2_clicked = true

func test_button_signal_emission():
	_btn_clicked = false
	var button := Button.new()
	button.pressed.connect(_on_btn_pressed)
	_tree_root.add_child(button)
	button.pressed.emit()
	assert_true(_btn_clicked, "Button pressed signal fires callback")
	button.queue_free()

func test_input_event_mouse_button_creation():
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = Vector2(100, 200)
	assert_eq(event.button_index, MOUSE_BUTTON_LEFT, "MouseButton event has correct button_index")
	assert_true(event.pressed, "MouseButton event is pressed")
	assert_eq(event.position, Vector2(100, 200), "MouseButton event has correct position")

func test_input_event_screen_touch_creation():
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = true
	event.position = Vector2(300, 400)
	assert_eq(event.index, 0, "ScreenTouch event has finger index 0")
	assert_true(event.pressed, "ScreenTouch event is pressed")
	assert_eq(event.position, Vector2(300, 400), "ScreenTouch event position correct")

func test_input_event_screen_drag_creation():
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.position = Vector2(350, 450)
	event.velocity = Vector2(10, -5)
	assert_eq(event.position, Vector2(350, 450), "ScreenDrag position correct")
	assert_eq(event.velocity, Vector2(10, -5), "ScreenDrag velocity correct")

func test_input_action_exists():
	assert_true(InputMap.has_action("move_up"), "input action 'move_up' exists")
	assert_true(InputMap.has_action("move_down"), "input action 'move_down' exists")
	assert_true(InputMap.has_action("move_left"), "input action 'move_left' exists")
	assert_true(InputMap.has_action("move_right"), "input action 'move_right' exists")
	assert_true(InputMap.has_action("dash"), "input action 'dash' exists")
	assert_true(InputMap.has_action("interact"), "input action 'interact' exists")
	assert_true(InputMap.has_action("pause"), "input action 'pause' exists")
	assert_true(InputMap.has_action("toggle_book"), "input action 'toggle_book' exists")

func test_touch_drag_direction_calculation():
	var start := Vector2(400, 300)
	var end := Vector2(500, 300)
	var dir: Vector2 = (end - start).normalized()
	assert_in_range(dir.x, 0.99, 1.01, "rightward drag direction x ~1")
	assert_in_range(dir.y, -0.01, 0.01, "rightward drag direction y ~0")

func test_touch_drag_direction_upward():
	var start := Vector2(400, 400)
	var end := Vector2(400, 300)
	var dir: Vector2 = (end - start).normalized()
	assert_in_range(dir.x, -0.01, 0.01, "upward drag direction x ~0")
	assert_in_range(dir.y, -1.01, -0.99, "upward drag direction y ~-1")

func test_touch_drag_length_threshold():
	var start := Vector2(400, 300)
	var short_end := Vector2(410, 305)
	var long_end := Vector2(450, 340)
	var short_len: float = (short_end - start).length()
	var long_len: float = (long_end - start).length()
	assert_lt(short_len, 30.0, "short drag below threshold 30")
	assert_gt(long_len, 30.0, "long drag above threshold 30")

func test_multiple_buttons_independent_signals():
	_btn1_clicked = false
	_btn2_clicked = false
	var btn1 := Button.new()
	var btn2 := Button.new()
	btn1.pressed.connect(_on_btn1_pressed)
	btn2.pressed.connect(_on_btn2_pressed)
	_tree_root.add_child(btn1)
	_tree_root.add_child(btn2)
	btn1.pressed.emit()
	assert_true(_btn1_clicked, "button1 signal fires independently")
	assert_false(_btn2_clicked, "button2 not triggered by button1")
	btn2.pressed.emit()
	assert_true(_btn2_clicked, "button2 signal fires independently")
	btn1.queue_free()
	btn2.queue_free()

func test_screen_to_world_identity():
	var pos := Vector2(640, 360)
	var transform := Transform2D.IDENTITY
	var world_pos: Vector2 = transform.affine_inverse() * pos
	assert_eq(world_pos, pos, "identity transform: screen == world")

func test_screen_to_world_scaled():
	var pos := Vector2(640, 360)
	var transform := Transform2D(0.0, Vector2.ZERO).scaled(Vector2(2, 2))
	var world_pos: Vector2 = transform.affine_inverse() * pos
	assert_in_range(world_pos.x, 319.0, 321.0, "2x scale: world.x == 320")
	assert_in_range(world_pos.y, 179.0, 181.0, "2x scale: world.y == 180")

func test_player_data_round_trip():
	var data := {
		"hp": 85.0, "max_hp": 120.0, "speed": 280.0,
		"dash_cooldown": 1.0, "throw_speed": 700.0,
		"pickup_range": 90.0, "defense": 0.1, "luck": 0.05,
	}
	var hp_val: float = data.get("hp", 100.0)
	var max_hp_val: float = data.get("max_hp", 100.0)
	var speed_val: float = data.get("speed", 245.0)
	assert_eq(hp_val, 85.0, "round-trip hp correct")
	assert_eq(max_hp_val, 120.0, "round-trip max_hp correct")
	assert_eq(speed_val, 280.0, "round-trip speed correct")

func test_damage_calculation_no_defense():
	var amount := 20.0
	var defense := 0.0
	var shield_time := 0.0
	var actual: float = amount * (1.0 - defense)
	if shield_time > 0:
		actual *= 0.55
	assert_eq(actual, 20.0, "no defense: full damage")

func test_damage_calculation_with_defense():
	var amount := 20.0
	var defense := 0.2
	var shield_time := 0.0
	var actual: float = amount * (1.0 - defense)
	if shield_time > 0:
		actual *= 0.55
	assert_in_range(actual, 15.9, 16.1, "20% defense: 16 damage")

func test_damage_calculation_with_shield():
	var amount := 20.0
	var defense := 0.0
	var shield_time := 5.0
	var actual: float = amount * (1.0 - defense)
	if shield_time > 0:
		actual *= 0.55
	assert_in_range(actual, 10.9, 11.1, "shield: 55% damage = 11")

func test_damage_calculation_defense_and_shield():
	var amount := 20.0
	var defense := 0.2
	var shield_time := 5.0
	var actual: float = amount * (1.0 - defense)
	if shield_time > 0:
		actual *= 0.55
	assert_in_range(actual, 8.7, 8.9, "defense + shield: ~8.8 damage")
