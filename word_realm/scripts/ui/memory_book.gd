# scripts/ui/memory_book.gd
extends Control

@onready var word_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/BookWordList

func _ready() -> void:
	visible = false

func toggle() -> void:
	visible = not visible
	if visible:
		_refresh()

func _refresh() -> void:
	for child in word_list.get_children():
		child.queue_free()
	for w in GameManager.run_words:
		var row := Label.new()
		row.text = "%s — %s (掌握度 %d)" % [w.word, w.meaning, w.mastery]
		word_list.add_child(row)
