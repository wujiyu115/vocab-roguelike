# tests/test_room_generator.gd
extends "res://tests/base_test.gd"

const RoomGenerator = preload("res://scripts/game/room_generator.gd")

var rg: RefCounted = null

func _init():
	_suite_name = "RoomGenerator"
	rg = RoomGenerator.new()

func test_circle_intersects_rect_inside():
	var result: bool = rg._circle_intersects_rect(Vector2(100, 100), 10.0, Rect2(80, 80, 40, 40))
	assert_true(result, "circle center inside rect intersects")

func test_circle_intersects_rect_outside():
	var result: bool = rg._circle_intersects_rect(Vector2(200, 200), 10.0, Rect2(80, 80, 40, 40))
	assert_false(result, "circle far from rect does not intersect")

func test_circle_intersects_rect_touching_edge():
	var result: bool = rg._circle_intersects_rect(Vector2(130, 100), 11.0, Rect2(80, 80, 40, 40))
	assert_true(result, "circle touching rect edge intersects")

func test_circle_intersects_rect_just_outside():
	var result: bool = rg._circle_intersects_rect(Vector2(130, 100), 9.0, Rect2(80, 80, 40, 40))
	assert_false(result, "circle just outside rect does not intersect")

func test_distance_point_to_rect_inside():
	var dist: float = rg._distance_point_to_rect(Vector2(100, 100), Rect2(80, 80, 40, 40))
	assert_eq(dist, 0.0, "point inside rect has distance 0")

func test_distance_point_to_rect_right():
	var dist: float = rg._distance_point_to_rect(Vector2(130, 100), Rect2(80, 80, 40, 40))
	assert_in_range(dist, 9.9, 10.1, "point 10 right of rect has distance ~10")

func test_distance_point_to_rect_above():
	var dist: float = rg._distance_point_to_rect(Vector2(100, 60), Rect2(80, 80, 40, 40))
	assert_in_range(dist, 19.9, 20.1, "point 20 above rect has distance ~20")

func test_distance_point_to_rect_diagonal():
	var dist: float = rg._distance_point_to_rect(Vector2(130, 130), Rect2(80, 80, 40, 40))
	var expected: float = sqrt(10.0 * 10.0 + 10.0 * 10.0)
	assert_in_range(dist, expected - 0.1, expected + 0.1, "diagonal distance correct")

func test_required_hits_low_room():
	GameManager.room = 2
	var entry := {"difficulty": 2, "shield": false}
	var needed: int = rg._required_hits(entry)
	assert_eq(needed, 1, "low room low difficulty needs 1 hit")
	GameManager.room = 0

func test_required_hits_high_room():
	GameManager.room = 6
	var entry := {"difficulty": 2, "shield": false}
	var needed: int = rg._required_hits(entry)
	assert_eq(needed, 2, "high room needs 2 hits")
	GameManager.room = 0

func test_required_hits_high_difficulty():
	GameManager.room = 2
	var entry := {"difficulty": 5, "shield": false}
	var needed: int = rg._required_hits(entry)
	assert_eq(needed, 2, "high difficulty needs 2 hits")
	GameManager.room = 0

func test_required_hits_with_shield():
	GameManager.room = 6
	var entry := {"difficulty": 2, "shield": true}
	var needed: int = rg._required_hits(entry)
	assert_eq(needed, 3, "shielded + high room needs 3 hits")
	GameManager.room = 0

func test_can_place_obstacle_valid():
	rg.obstacles.clear()
	var data := {"bounds": Rect2(300, 300, 60, 40)}
	var result: bool = rg._can_place_obstacle(data, Vector2(640, 480))
	assert_true(result, "valid position can place obstacle")

func test_can_place_obstacle_too_close_to_player():
	rg.obstacles.clear()
	var data := {"bounds": Rect2(630, 470, 20, 20)}
	var result: bool = rg._can_place_obstacle(data, Vector2(640, 480))
	assert_false(result, "too close to player cannot place")

func test_can_place_obstacle_near_top_edge():
	rg.obstacles.clear()
	var data := {"bounds": Rect2(300, 10, 60, 40)}
	var result: bool = rg._can_place_obstacle(data, Vector2(640, 480))
	assert_false(result, "near top edge cannot place")

func test_can_place_obstacle_overlapping_existing():
	rg.obstacles.clear()
	rg.obstacles.append(Rect2(300, 300, 60, 40))
	var data := {"bounds": Rect2(310, 310, 50, 30)}
	var result: bool = rg._can_place_obstacle(data, Vector2(640, 480))
	assert_false(result, "overlapping existing obstacle cannot place")
	rg.obstacles.clear()

func test_pick_monster_kind_valid():
	var entry := {"difficulty": 1}
	GameManager.room = 1
	var kind: int = rg._pick_monster_kind(entry)
	assert_true(kind >= 0 and kind <= 4, "monster kind in valid range")
	GameManager.room = 0

func test_pick_monster_kind_high_tier():
	var entry := {"difficulty": 8}
	GameManager.room = 10
	var got_non_wanderer := false
	for i in range(50):
		var kind: int = rg._pick_monster_kind(entry)
		if kind != GameManager.MonsterKind.WANDERER:
			got_non_wanderer = true
			break
	assert_true(got_non_wanderer, "high tier sometimes picks non-WANDERER")
	GameManager.room = 0
