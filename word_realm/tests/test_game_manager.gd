# tests/test_game_manager.gd
extends "res://tests/base_test.gd"

var _signal_received := false
var _signal_state := -1

func _init():
	_suite_name = "GameManager"

func _on_state_changed(s: int) -> void:
	_signal_received = true
	_signal_state = s

func test_state_enum_values():
	assert_eq(GameManager.State.MENU, 0, "State.MENU == 0")
	assert_eq(GameManager.State.PLAYING, 1, "State.PLAYING == 1")
	assert_eq(GameManager.State.ROOM_CLEAR, 2, "State.ROOM_CLEAR == 2")
	assert_eq(GameManager.State.REWARD_CHOICE, 3, "State.REWARD_CHOICE == 3")
	assert_eq(GameManager.State.GAME_OVER, 4, "State.GAME_OVER == 4")
	assert_eq(GameManager.State.WIN, 5, "State.WIN == 5")
	assert_eq(GameManager.State.PAUSED, 6, "State.PAUSED == 6")

func test_monster_kind_enum():
	assert_eq(GameManager.MonsterKind.WANDERER, 0, "MonsterKind.WANDERER == 0")
	assert_eq(GameManager.MonsterKind.CHASER, 1, "MonsterKind.CHASER == 1")
	assert_eq(GameManager.MonsterKind.DASHER, 2, "MonsterKind.DASHER == 2")
	assert_eq(GameManager.MonsterKind.SHIELD, 3, "MonsterKind.SHIELD == 3")
	assert_eq(GameManager.MonsterKind.GHOST, 4, "MonsterKind.GHOST == 4")

func test_drop_kind_enum():
	assert_eq(GameManager.DropKind.APPLE, 0, "DropKind.APPLE == 0")
	assert_eq(GameManager.DropKind.GLOVES, 6, "DropKind.GLOVES == 6")

func test_reward_kind_enum():
	assert_eq(GameManager.RewardKind.SURVIVAL, 0, "RewardKind.SURVIVAL == 0")
	assert_eq(GameManager.RewardKind.CHEST_ECHO, 5, "RewardKind.CHEST_ECHO == 5")

func test_initial_state():
	assert_eq(GameManager.current_state, GameManager.State.MENU, "initial state is MENU")

func test_change_state():
	var old_state: int = GameManager.current_state
	GameManager.change_state(GameManager.State.PLAYING)
	assert_eq(GameManager.current_state, GameManager.State.PLAYING, "state changed to PLAYING")
	assert_eq(GameManager.previous_state, old_state, "previous_state recorded")
	GameManager.change_state(old_state)

func test_state_changed_signal():
	_signal_received = false
	_signal_state = -1
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.change_state(GameManager.State.WIN)
	assert_true(_signal_received, "state_changed signal emitted")
	assert_eq(_signal_state, GameManager.State.WIN, "signal carries new state")
	GameManager.state_changed.disconnect(_on_state_changed)
	GameManager.change_state(GameManager.State.MENU)

func test_theme_count():
	assert_eq(GameManager.themes.size(), 8, "8 themes defined")

func test_background_names_count():
	assert_eq(GameManager.background_names.size(), 8, "8 background names")

func test_themes_have_required_keys():
	var theme: Dictionary = GameManager.themes[0]
	assert_has_key(theme, "name", "theme has 'name'")
	assert_has_key(theme, "floor", "theme has 'floor'")
	assert_has_key(theme, "wall", "theme has 'wall'")
	assert_has_key(theme, "accent", "theme has 'accent'")

func test_get_theme_index_valid_range():
	GameManager.room = 1
	var idx: int = GameManager.get_theme_index()
	assert_in_range(float(idx), 0.0, 7.0, "theme index in range for room=1")
	GameManager.room = 9
	idx = GameManager.get_theme_index()
	assert_in_range(float(idx), 0.0, 7.0, "theme index in range for room=9")
	GameManager.room = 16
	idx = GameManager.get_theme_index()
	assert_in_range(float(idx), 0.0, 7.0, "theme index in range for room=16")
	GameManager.room = 0

func test_get_theme_index_wraps():
	GameManager.room = 1
	var idx1: int = GameManager.get_theme_index()
	GameManager.room = 9
	var idx9: int = GameManager.get_theme_index()
	assert_eq(idx1, idx9, "theme index wraps at room 9")
	GameManager.room = 0

func test_constants():
	assert_eq(GameManager.W, 1280, "W == 1280")
	assert_eq(GameManager.H, 720, "H == 720")

func test_reset_run():
	GameManager.room = 5
	GameManager.combo = 3
	GameManager.streak_wrong = 2
	GameManager.correct_hits = 10
	GameManager.wrong_hits = 4
	GameManager.collisions = 2
	GameManager.room_difficulty_scale = 1.2
	GameManager.speed_boost_rooms = 3
	GameManager.piercing_ink_rooms = 2
	GameManager.temp_speed_bonus = 15.0
	GameManager.run_words.append({"word": "test"})
	GameManager.reset_run()
	assert_eq(GameManager.room, 0, "room reset to 0")
	assert_eq(GameManager.combo, 0, "combo reset to 0")
	assert_eq(GameManager.streak_wrong, 0, "streak_wrong reset to 0")
	assert_eq(GameManager.correct_hits, 0, "correct_hits reset to 0")
	assert_eq(GameManager.wrong_hits, 0, "wrong_hits reset to 0")
	assert_eq(GameManager.collisions, 0, "collisions reset to 0")
	assert_eq(GameManager.room_difficulty_scale, 1.0, "difficulty_scale reset to 1.0")
	assert_eq(GameManager.speed_boost_rooms, 0, "speed_boost_rooms reset to 0")
	assert_eq(GameManager.piercing_ink_rooms, 0, "piercing_ink_rooms reset to 0")
	assert_eq(GameManager.temp_speed_bonus, 0.0, "temp_speed_bonus reset to 0.0")
	assert_eq(GameManager.run_words.size(), 0, "run_words cleared")

func test_is_mobile_is_bool():
	assert_true(typeof(GameManager.is_mobile) == TYPE_BOOL, "is_mobile is bool")
