# scripts/ui/main_menu.gd
extends Control

@onready var easy_btn: Button = %EasyButton
@onready var normal_btn: Button = %NormalButton
@onready var hard_btn: Button = %HardButton
@onready var start_btn: Button = %StartButton
@onready var continue_btn: Button = %ContinueButton
@onready var selected_label: Label = %SelectedLabel
@onready var hint_label: Label = %HintLabel

var difficulty_buttons: Array[Button] = []

func _ready():
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

	_update_selection()

	if GameManager.is_mobile:
		hint_label.text = "点击地面移动 · 拖拽射击 · 按钮拾取/冲刺"
	else:
		hint_label.text = "WASD 移动  鼠标瞄准  左键发射  E 拾取  Space 闪避  Tab 记忆书"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: _on_difficulty(2, "简单 / 高中词汇")
			KEY_2: _on_difficulty(4, "普通 / 四六级词汇")
			KEY_3: _on_difficulty(6, "困难 / 雅思词汇")
			KEY_ENTER, KEY_KP_ENTER: _on_start()

func _on_difficulty(mode: int, name: String) -> void:
	GameManager.selected_mode = mode
	GameManager.selected_mode_name = name
	_update_selection()

func _update_selection() -> void:
	selected_label.text = "当前选择：" + GameManager.selected_mode_name
	for i in range(difficulty_buttons.size()):
		var modes := [2, 4, 6]
		difficulty_buttons[i].button_pressed = (GameManager.selected_mode == modes[i])

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
