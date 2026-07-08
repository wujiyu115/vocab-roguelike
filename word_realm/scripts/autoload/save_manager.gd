# scripts/autoload/save_manager.gd
extends Node

const SAVE_PATH := "user://savegame.json"

var save_data := {
	"words": [],
	"best_room": 0,
	"total_correct": 0,
	"total_wrong": 0,
	"has_continue": false,
	"continue_state": {},
}

func _ready():
	load_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if GameManager.current_state in [GameManager.State.PLAYING, GameManager.State.ROOM_CLEAR, GameManager.State.PAUSED, GameManager.State.REWARD_CHOICE]:
			save_game()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		return
	if json.data is Dictionary:
		save_data.merge(json.data, true)
	WordBank.merge_saved_stats(save_data.get("words", []))

func save_game() -> void:
	save_data.words = []
	for w in WordBank.all_words:
		save_data.words.append({
			"word": w.word,
			"seen_count": w.seen_count,
			"correct_count": w.correct_count,
			"wrong_count": w.wrong_count,
			"death_count": w.death_count,
			"mastery": w.mastery,
			"last_seen_room": w.last_seen_room,
		})
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(save_data))
	file.close()

func save_continue_state(player_data: Dictionary) -> void:
	save_data.has_continue = true
	save_data.continue_state = {
		"mode": GameManager.selected_mode,
		"mode_name": GameManager.selected_mode_name,
		"room": maxi(1, GameManager.room),
		"hp": player_data.get("hp", 100.0),
		"max_hp": player_data.get("max_hp", 100.0),
		"speed": player_data.get("speed", 245.0),
		"dash_cooldown": player_data.get("dash_cooldown", 1.2),
		"throw_speed": player_data.get("throw_speed", 610.0),
		"pickup_range": player_data.get("pickup_range", 84.0),
		"defense": player_data.get("defense", 0.0),
		"luck": player_data.get("luck", 0.0),
		"piercing_ink_rooms": GameManager.piercing_ink_rooms,
		"echo_scroll_rooms": GameManager.echo_scroll_rooms,
		"speed_boost_rooms": GameManager.speed_boost_rooms,
		"throw_boost_rooms": GameManager.throw_boost_rooms,
		"dash_boost_rooms": GameManager.dash_boost_rooms,
		"pickup_boost_rooms": GameManager.pickup_boost_rooms,
		"temp_speed_bonus": GameManager.temp_speed_bonus,
		"temp_throw_bonus": GameManager.temp_throw_bonus,
		"temp_dash_bonus": GameManager.temp_dash_bonus,
		"temp_pickup_bonus": GameManager.temp_pickup_bonus,
	}
	save_game()

func has_continue() -> bool:
	return save_data.get("has_continue", false)

func get_continue_state() -> Dictionary:
	return save_data.get("continue_state", {})

func clear_continue() -> void:
	save_data.has_continue = false
	save_data.continue_state = {}
