# scripts/ui/main_menu.gd
extends Control

@onready var easy_btn: Button = %EasyButton
@onready var normal_btn: Button = %NormalButton
@onready var hard_btn: Button = %HardButton
@onready var start_btn: Button = %StartButton
@onready var continue_btn: Button = %ContinueButton
@onready var selected_label: Label = %SelectedLabel
@onready var stats_label: Label = %StatsLabel
@onready var hint_label: Label = %HintLabel
@onready var frame: PanelContainer = %Frame
@onready var floating_words: Control = $FloatingWords

var difficulty_buttons: Array[Button] = []

const CARD_COLORS := [
	Color(0.24, 0.30, 0.16),
	Color(0.20, 0.20, 0.25),
	Color(0.28, 0.17, 0.22),
]
const CARD_COLORS_SELECTED := [
	Color(0.32, 0.40, 0.20),
	Color(0.28, 0.28, 0.34),
	Color(0.38, 0.22, 0.30),
]
const CARD_BORDERS := [
	Color(0.45, 0.55, 0.28),
	Color(0.40, 0.40, 0.50),
	Color(0.50, 0.30, 0.42),
]

const BUBBLE_WORDS := ["strategy", "increase", "curious", "adventure", "vocabulary",
	"explore", "achieve", "courage", "discover", "wisdom"]
const BUBBLE_COLORS := [
	Color(0.75, 0.35, 0.45), Color(0.45, 0.55, 0.75), Color(0.65, 0.50, 0.70),
	Color(0.50, 0.65, 0.40), Color(0.70, 0.55, 0.30), Color(0.55, 0.40, 0.65),
	Color(0.40, 0.60, 0.60), Color(0.70, 0.40, 0.50), Color(0.50, 0.50, 0.70),
	Color(0.60, 0.45, 0.35),
]

var bubble_data: Array[Dictionary] = []

func _ready() -> void:
	difficulty_buttons = [easy_btn, normal_btn, hard_btn]
	easy_btn.pressed.connect(_on_difficulty.bind(2, "简单 / 高中词汇"))
	normal_btn.pressed.connect(_on_difficulty.bind(4, "普通 / 四六级词汇"))
	hard_btn.pressed.connect(_on_difficulty.bind(6, "困难 / 雅思词汇"))
	start_btn.pressed.connect(_on_start)
	continue_btn.pressed.connect(_on_continue)

	continue_btn.visible = SaveManager.has_continue()
	if SaveManager.has_continue():
		var cs := SaveManager.get_continue_state()
		continue_btn.text = "继续游戏：第 %d 间" % cs.get("room", 1)

	_apply_styles()
	_create_floating_bubbles()
	_update_selection()
	_update_stats()

	if GameManager.is_mobile:
		hint_label.text = "点击地面移动 · 拖拽射击 · 按钮拾取/冲刺"
	else:
		hint_label.text = "操作：WASD 移动  鼠标瞄准  左键发射  E 拾取  Space 冲刺  Tab 记忆书"

func _apply_styles() -> void:
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.09, 0.10, 0.14, 0.85)
	frame_style.border_color = Color(0.22, 0.25, 0.32, 0.6)
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(16)
	frame.add_theme_stylebox_override("panel", frame_style)

	for i in range(3):
		_style_card(difficulty_buttons[i], CARD_COLORS[i], CARD_BORDERS[i])

	_style_start_button()
	_style_continue_button()

func _style_card(btn: Button, bg: Color, border: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.border_color = border.darkened(0.3)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)
	normal.set_content_margin_all(12)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = bg.lightened(0.1)
	hover.border_color = border
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = bg.lightened(0.15)
	pressed.border_color = border.lightened(0.2)
	pressed.set_border_width_all(3)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.92))

func _style_start_button() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.78, 0.60, 0.18)
	normal.set_corner_radius_all(10)
	normal.set_content_margin_all(8)
	start_btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = Color(0.85, 0.67, 0.22)
	start_btn.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.70, 0.52, 0.14)
	start_btn.add_theme_stylebox_override("pressed", pressed)

	start_btn.add_theme_color_override("font_color", Color(0.1, 0.08, 0.05))
	start_btn.add_theme_color_override("font_hover_color", Color(0.1, 0.08, 0.05))
	start_btn.add_theme_color_override("font_pressed_color", Color(0.1, 0.08, 0.05))

func _style_continue_button() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.18, 0.20, 0.26)
	normal.border_color = Color(0.30, 0.33, 0.40)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(10)
	normal.set_content_margin_all(8)
	continue_btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = Color(0.24, 0.26, 0.32)
	hover.border_color = Color(0.40, 0.43, 0.50)
	continue_btn.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.14, 0.16, 0.22)
	continue_btn.add_theme_stylebox_override("pressed", pressed)

	continue_btn.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))

func _create_floating_bubbles() -> void:
	var positions := [
		Vector2(0.08, 0.18), Vector2(0.92, 0.15),
		Vector2(0.05, 0.55), Vector2(0.95, 0.50),
		Vector2(0.10, 0.82), Vector2(0.90, 0.80),
		Vector2(0.03, 0.38), Vector2(0.97, 0.35),
		Vector2(0.07, 0.70), Vector2(0.93, 0.68),
	]
	for i in range(mini(BUBBLE_WORDS.size(), positions.size())):
		var bubble := _make_bubble(BUBBLE_WORDS[i], BUBBLE_COLORS[i], positions[i])
		floating_words.add_child(bubble)
		bubble_data.append({
			"node": bubble,
			"base_pos": positions[i],
			"phase": randf() * TAU,
			"speed": 0.4 + randf() * 0.6,
			"amplitude": 6.0 + randf() * 8.0,
		})

func _make_bubble(word: String, color: Color, anchor: Vector2) -> Control:
	var container := Control.new()
	container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.color = color.darkened(0.2)
	bg.color.a = 0.55
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var lbl := Label.new()
	lbl.text = word
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color.lightened(0.3))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var text_size := lbl.get_theme_font("font").get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	var w := text_size.x + 24
	var h := text_size.y + 16
	var radius := maxf(w, h) * 0.5 + 4

	bg.position = Vector2(-radius, -radius)
	bg.size = Vector2(radius * 2, radius * 2)

	lbl.position = Vector2(-w * 0.5, -h * 0.5)
	lbl.size = Vector2(w, h)

	container.add_child(bg)
	container.add_child(lbl)

	var vp_size := get_viewport_rect().size
	if vp_size.x < 1:
		vp_size = Vector2(1280, 720)
	container.position = Vector2(anchor.x * vp_size.x, anchor.y * vp_size.y)

	return container

func _process(delta: float) -> void:
	var vp_size := get_viewport_rect().size
	for bd in bubble_data:
		bd.phase += delta * bd.speed
		var base := Vector2(bd.base_pos.x * vp_size.x, bd.base_pos.y * vp_size.y)
		var node: Control = bd.node
		node.position = base + Vector2(sin(bd.phase) * bd.amplitude, cos(bd.phase * 0.7) * bd.amplitude * 0.6)
		node.modulate.a = 0.5 + sin(bd.phase * 0.5) * 0.15

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: _on_difficulty(2, "简单 / 高中词汇")
			KEY_2: _on_difficulty(4, "普通 / 四六级词汇")
			KEY_3: _on_difficulty(6, "困难 / 雅思词汇")
			KEY_ENTER, KEY_KP_ENTER: _on_start()
			KEY_F11: _toggle_fullscreen()

func _toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _on_difficulty(mode: int, label_name: String) -> void:
	GameManager.selected_mode = mode
	GameManager.selected_mode_name = label_name
	_update_selection()

func _update_selection() -> void:
	selected_label.text = "当前选择：" + GameManager.selected_mode_name
	var modes := [2, 4, 6]
	for i in range(difficulty_buttons.size()):
		var btn := difficulty_buttons[i]
		var is_selected: bool = GameManager.selected_mode == modes[i]
		btn.button_pressed = is_selected
		if is_selected:
			_style_card(btn, CARD_COLORS_SELECTED[i], CARD_BORDERS[i])
		else:
			_style_card(btn, CARD_COLORS[i], CARD_BORDERS[i])

func _update_stats() -> void:
	var best: int = SaveManager.save_data.best_room
	var correct: int = SaveManager.save_data.total_correct
	var wrong: int = SaveManager.save_data.total_wrong
	var total: int = WordBank.all_words.size()
	var bank: int = WordBank.bank_words.size()
	stats_label.text = "词库：%d/%d  最高纪录：第 %d 间  正确 %d  错误 %d    Enter 开始  F11 全屏" % [bank, total, best, correct, wrong]

func _on_start() -> void:
	WordBank.set_difficulty(GameManager.selected_mode)
	GameManager.reset_run()
	GameManager.change_state(GameManager.State.PLAYING)
	SaveManager.clear_continue()
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")

func _on_continue() -> void:
	if not SaveManager.has_continue():
		return
	var cs := SaveManager.get_continue_state()
	GameManager.selected_mode = cs.get("mode", 2)
	GameManager.selected_mode_name = cs.get("mode_name", "简单 / 高中词汇")
	WordBank.set_difficulty(GameManager.selected_mode)
	GameManager.reset_run()
	GameManager.room = cs.get("room", 1) - 1
	GameManager.change_state(GameManager.State.PLAYING)
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")
