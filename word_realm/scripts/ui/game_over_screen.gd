# scripts/ui/game_over_screen.gd
extends Control

signal return_to_menu

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var message_label: Label = $VBoxContainer/MessageLabel
@onready var word_list: VBoxContainer = $VBoxContainer/ScrollContainer/WordList
@onready var return_button: Button = $VBoxContainer/ReturnButton

func _ready() -> void:
	visible = false
	return_button.pressed.connect(func(): return_to_menu.emit())

func show_screen(title: String, msg: String, words: Array) -> void:
	visible = true
	title_label.text = title
	message_label.text = msg
	for child in word_list.get_children():
		child.queue_free()
	var seen := {}
	for w in words:
		if w.word in seen:
			continue
		seen[w.word] = true
		var row := Label.new()
		row.text = "%s  %s  正确%d / 错误%d / 死亡%d" % [w.word, w.meaning, w.correct_count, w.wrong_count, w.death_count]
		word_list.add_child(row)
		if seen.size() >= 18:
			break

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		return_to_menu.emit()
	if event is InputEventScreenTouch and event.pressed:
		return_to_menu.emit()
