# scripts/ui/game_over_screen.gd
extends Control

signal return_to_menu

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var message_label: Label = $VBoxContainer/MessageLabel
@onready var scroll_container: ScrollContainer = $VBoxContainer/ScrollContainer
@onready var word_list: VBoxContainer = $VBoxContainer/ScrollContainer/WordList
@onready var return_button: Button = $VBoxContainer/ReturnButton

func _ready() -> void:
	visible = false
	return_button.pressed.connect(func(): return_to_menu.emit())

func show_screen(title: String, msg: String, words: Array) -> void:
	visible = true
	title_label.text = title
	for child in word_list.get_children():
		child.queue_free()

	# 去重后显示全部本局词汇（不再截断为 18 个），ScrollContainer 负责滚动
	var seen := {}
	var unique: Array = []
	for w in words:
		if w.word in seen:
			continue
		seen[w.word] = true
		unique.append(w)

	for w in unique:
		var row := Label.new()
		row.text = "%s  %s  正确%d / 错误%d / 死亡%d" % [w.word, w.meaning, w.correct_count, w.wrong_count, w.death_count]
		word_list.add_child(row)

	var hint := "拖动查看词表 · 点击按钮返回" if GameManager.is_mobile else "鼠标滚轮 / ↑↓ / PgUp·PgDn 滚动，Enter 返回"
	message_label.text = "%s\n本局词汇回顾 %d 词 · %s" % [msg, unique.size(), hint]
	scroll_container.scroll_vertical = 0

func _scroll_by(amount: float) -> void:
	scroll_container.scroll_vertical += int(amount)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER:
				return_to_menu.emit()
			KEY_UP:
				_scroll_by(-40)
			KEY_DOWN:
				_scroll_by(40)
			KEY_PAGEUP:
				_scroll_by(-scroll_container.size.y)
			KEY_PAGEDOWN:
				_scroll_by(scroll_container.size.y)
			KEY_HOME:
				scroll_container.scroll_vertical = 0
			KEY_END:
				scroll_container.scroll_vertical = int(scroll_container.get_v_scroll_bar().max_value)
