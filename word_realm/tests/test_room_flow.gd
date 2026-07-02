# tests/test_room_flow.gd
extends "res://tests/base_test.gd"

func _init():
	_suite_name = "RoomFlow"

# 回归测试：清完一间房进入下一间后，玩法功能（碰撞掉血 / 拾取 / 开火）
# 依赖 GameManager.current_state == PLAYING（见 game.gd 的 _physics_process 与
# _unhandled_input 守卫）。_on_room_cleared() 会把状态切到 ROOM_CLEAR，随后调用
# _start_room()。若 _start_room() 不把状态设回 PLAYING，第 2 间起所有玩法逻辑
# 都会被守卫挡掉。
func test_start_room_restores_playing_state():
	var game: Node = load("res://scenes/game/game.tscn").instantiate()
	_tree_root.add_child(game)
	# headless 测试下 add_child 不一定会同步触发 _ready()，手动补一次以
	# 初始化 @onready 节点并生成第 1 间
	if game.player == null:
		game._ready()

	# 模拟清房后的状态（_on_room_cleared 结束时处于 ROOM_CLEAR）
	GameManager.change_state(GameManager.State.ROOM_CLEAR)
	game._start_room()
	assert_eq(GameManager.current_state, GameManager.State.PLAYING,
		"进入下一间后状态恢复为 PLAYING")

	game.queue_free()
	GameManager.reset_run()
	GameManager.change_state(GameManager.State.MENU)
