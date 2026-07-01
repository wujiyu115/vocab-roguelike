# tests/test_monster_logic.gd
extends "res://tests/base_test.gd"

func _init():
	_suite_name = "MonsterLogic"

func _make_entry() -> Dictionary:
	return {
		"word": "test",
		"meaning": "testing_meaning",
		"difficulty": 2,
		"frequency_rank": 1000,
		"tags": ["verb"],
		"seen_count": 1,
		"correct_count": 0,
		"wrong_count": 0,
		"death_count": 0,
		"mastery": 0,
		"last_seen_room": 1,
	}

func _make_monster(entry: Dictionary, monster_hp: float, shield: bool) -> CharacterBody2D:
	var monster := CharacterBody2D.new()
	monster.set_script(load("res://scripts/game/monster.gd"))
	monster.entry = entry
	monster.hp = monster_hp
	monster.max_hp = monster_hp
	monster.shield_up = shield
	monster.kind = GameManager.MonsterKind.WANDERER
	monster.rage_timer = 0.0
	return monster

func _reset_gm_state() -> void:
	GameManager.correct_hits = 0
	GameManager.wrong_hits = 0
	GameManager.combo = 0
	GameManager.streak_wrong = 0
	SaveManager.save_data.total_correct = 0
	SaveManager.save_data.total_wrong = 0

func test_take_hit_correct_meaning():
	_reset_gm_state()
	var entry := _make_entry()
	var monster := _make_monster(entry, 1.0, false)
	var result: Dictionary = monster.take_hit("testing_meaning", false)
	assert_true(result.correct, "correct meaning returns correct=true")
	assert_true(result.killed, "1 HP monster killed by correct hit")
	assert_eq(GameManager.correct_hits, 1, "correct_hits incremented")
	assert_eq(entry.correct_count, 1, "entry.correct_count incremented")
	monster.free()

func test_take_hit_wrong_meaning():
	_reset_gm_state()
	var entry := _make_entry()
	var monster := _make_monster(entry, 2.0, false)
	var result: Dictionary = monster.take_hit("wrong_meaning", false)
	assert_false(result.correct, "wrong meaning returns correct=false")
	assert_false(result.killed, "wrong hit does not kill")
	assert_eq(GameManager.wrong_hits, 1, "wrong_hits incremented")
	assert_eq(entry.wrong_count, 1, "entry.wrong_count incremented")
	assert_gt(monster.rage_timer, 0.0, "rage_timer set on wrong hit")
	monster.free()

func test_take_hit_universal():
	_reset_gm_state()
	var entry := _make_entry()
	var monster := _make_monster(entry, 1.0, false)
	var result: Dictionary = monster.take_hit("any_meaning", true)
	assert_true(result.correct, "universal always returns correct=true")
	assert_eq(entry.correct_count, 0, "universal does not increment correct_count")
	monster.free()

func test_take_hit_shield_break():
	_reset_gm_state()
	var entry := _make_entry()
	var monster := _make_monster(entry, 2.0, true)
	var result: Dictionary = monster.take_hit("testing_meaning", false)
	assert_true(result.correct, "shield break is correct")
	assert_true(result.get("shield_break", false), "shield_break flag set")
	assert_false(result.killed, "shield break does not kill")
	assert_false(monster.shield_up, "shield removed after break")
	assert_eq(monster.hp, 2.0, "HP unchanged after shield break")
	monster.free()

func test_take_hit_after_shield_break():
	_reset_gm_state()
	var entry := _make_entry()
	var monster := _make_monster(entry, 2.0, true)
	monster.take_hit("testing_meaning", false)
	var result: Dictionary = monster.take_hit("testing_meaning", false)
	assert_true(result.correct, "second hit after shield break is correct")
	assert_false(result.get("shield_break", false), "no shield_break on second hit")
	assert_lt(monster.hp, 2.0, "HP reduced after second hit")
	monster.free()

func test_combo_increments_on_correct():
	_reset_gm_state()
	var entry := _make_entry()
	var monster := _make_monster(entry, 5.0, false)
	monster.take_hit("testing_meaning", false)
	assert_eq(GameManager.combo, 1, "combo is 1 after first hit")
	monster.take_hit("testing_meaning", false)
	assert_eq(GameManager.combo, 2, "combo is 2 after second hit")
	monster.free()

func test_combo_resets_on_wrong():
	_reset_gm_state()
	GameManager.combo = 5
	var entry := _make_entry()
	var monster := _make_monster(entry, 5.0, false)
	monster.take_hit("wrong_meaning", false)
	assert_eq(GameManager.combo, 0, "combo resets to 0 on wrong hit")
	monster.free()

func test_streak_wrong_increments():
	_reset_gm_state()
	var entry := _make_entry()
	var monster := _make_monster(entry, 5.0, false)
	monster.take_hit("wrong1", false)
	assert_eq(GameManager.streak_wrong, 1, "streak_wrong is 1 after first wrong")
	monster.free()

func test_mastery_increases_on_correct():
	_reset_gm_state()
	var entry := _make_entry()
	entry.mastery = 3
	var monster := _make_monster(entry, 5.0, false)
	monster.take_hit("testing_meaning", false)
	assert_eq(entry.mastery, 4, "mastery +1 on correct hit")
	monster.free()

func test_mastery_decreases_on_wrong():
	_reset_gm_state()
	var entry := _make_entry()
	entry.mastery = 3
	var monster := _make_monster(entry, 5.0, false)
	monster.take_hit("wrong_meaning", false)
	assert_eq(entry.mastery, 2, "mastery -1 on wrong hit")
	monster.free()

func test_mastery_clamped_at_zero():
	_reset_gm_state()
	var entry := _make_entry()
	entry.mastery = 0
	var monster := _make_monster(entry, 5.0, false)
	monster.take_hit("wrong_meaning", false)
	assert_eq(entry.mastery, 0, "mastery does not go below 0")
	monster.free()

func test_mastery_capped_at_ten():
	_reset_gm_state()
	var entry := _make_entry()
	entry.mastery = 10
	var monster := _make_monster(entry, 5.0, false)
	monster.take_hit("testing_meaning", false)
	assert_eq(entry.mastery, 10, "mastery capped at 10")
	monster.free()

func test_wrong_hit_reduces_hp_slightly():
	_reset_gm_state()
	var entry := _make_entry()
	var monster := _make_monster(entry, 5.0, false)
	monster.take_hit("wrong_meaning", false)
	assert_in_range(monster.hp, 4.8, 4.9, "wrong hit reduces HP by 0.15")
	monster.free()

func test_combo_bonus_damage():
	_reset_gm_state()
	GameManager.combo = 2
	var entry := _make_entry()
	var monster := _make_monster(entry, 5.0, false)
	var result: Dictionary = monster.take_hit("testing_meaning", false)
	var damage_val: float = result.get("damage", 0.0)
	assert_gt(damage_val, 1.0, "combo >= 3 grants bonus damage")
	monster.free()

func test_save_data_updated_on_correct():
	_reset_gm_state()
	var entry := _make_entry()
	var monster := _make_monster(entry, 1.0, false)
	monster.take_hit("testing_meaning", false)
	assert_eq(SaveManager.save_data.total_correct, 1, "save_data.total_correct incremented")
	monster.free()

func test_save_data_updated_on_wrong():
	_reset_gm_state()
	var entry := _make_entry()
	var monster := _make_monster(entry, 5.0, false)
	monster.take_hit("wrong_meaning", false)
	assert_eq(SaveManager.save_data.total_wrong, 1, "save_data.total_wrong incremented")
	monster.free()
