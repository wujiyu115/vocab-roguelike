# scripts/autoload/game_manager.gd
extends Node

signal state_changed(new_state: int)

enum State { MENU, PLAYING, ROOM_CLEAR, REWARD_CHOICE, GAME_OVER, WIN, PAUSED }
enum MonsterKind { WANDERER, CHASER, DASHER, SHIELD, GHOST }
enum DropKind { APPLE, COFFEE, SHIELD_POTION, INK, BOOTS, FEATHER, GLOVES }
enum RewardKind { SURVIVAL, MOVE_SPEED, SHIELD, CHEST_SPEED, CHEST_THROW, CHEST_ECHO }

const W := 1280
const H := 720
const DT := 1.0 / 60.0

var current_state: int = State.MENU
var previous_state: int = State.MENU
var room := 0
var combo := 0
var streak_wrong := 0
var correct_hits := 0
var wrong_hits := 0
var collisions := 0
var room_time := 0.0
var room_difficulty_scale := 1.0
var selected_mode := 2
var selected_mode_name := "简单 / 高中词汇"
var message := "选择难度后开始探险"

# 限时增益计数器
var speed_boost_rooms := 0
var throw_boost_rooms := 0
var dash_boost_rooms := 0
var pickup_boost_rooms := 0
var piercing_ink_rooms := 0
var echo_scroll_rooms := 0
var temp_speed_bonus := 0.0
var temp_throw_bonus := 0.0
var temp_dash_bonus := 0.0
var temp_pickup_bonus := 0.0

var run_words: Array[Dictionary] = []
var is_mobile := false

# 房间主题数据，对照 WordRogue.cs:430-442
var themes := [
	{"name": "新手森林", "floor": Color(0.129, 0.243, 0.176), "wall": Color(0.075, 0.141, 0.122), "accent": Color(0.463, 0.722, 0.384)},
	{"name": "办公废墟", "floor": Color(0.227, 0.239, 0.259), "wall": Color(0.125, 0.133, 0.153), "accent": Color(0.878, 0.686, 0.361)},
	{"name": "校园图书馆", "floor": Color(0.227, 0.188, 0.294), "wall": Color(0.129, 0.110, 0.188), "accent": Color(0.604, 0.522, 0.788)},
	{"name": "科技实验室", "floor": Color(0.137, 0.247, 0.286), "wall": Color(0.078, 0.145, 0.173), "accent": Color(0.290, 0.741, 0.776)},
	{"name": "商业矿井", "floor": Color(0.282, 0.227, 0.165), "wall": Color(0.157, 0.125, 0.106), "accent": Color(0.890, 0.737, 0.365)},
	{"name": "学术神殿", "floor": Color(0.200, 0.208, 0.294), "wall": Color(0.110, 0.122, 0.188), "accent": Color(0.863, 0.859, 0.651)},
	{"name": "旅行港口", "floor": Color(0.137, 0.286, 0.337), "wall": Color(0.086, 0.169, 0.212), "accent": Color(0.416, 0.694, 0.867)},
	{"name": "情绪洞穴", "floor": Color(0.290, 0.176, 0.227), "wall": Color(0.165, 0.106, 0.141), "accent": Color(0.894, 0.478, 0.545)},
]

var background_names := [
	"forest.jpg", "office.jpg", "library.jpg", "lab.jpg",
	"business_mine.jpg", "academic_temple.jpg", "travel_port.jpg", "emotion_cave.jpg"
]

func _ready():
	var os_name := OS.get_name()
	is_mobile = os_name in ["Android", "iOS"]

func change_state(new_state: int) -> void:
	previous_state = current_state
	current_state = new_state
	state_changed.emit(new_state)

func get_theme_index() -> int:
	return (room - 1 + themes.size()) % themes.size()

func get_current_theme() -> Dictionary:
	return themes[get_theme_index()]

func reset_run() -> void:
	room = 0
	combo = 0
	streak_wrong = 0
	correct_hits = 0
	wrong_hits = 0
	collisions = 0
	room_difficulty_scale = 1.0
	speed_boost_rooms = 0
	throw_boost_rooms = 0
	dash_boost_rooms = 0
	pickup_boost_rooms = 0
	piercing_ink_rooms = 0
	echo_scroll_rooms = 0
	temp_speed_bonus = 0.0
	temp_throw_bonus = 0.0
	temp_dash_bonus = 0.0
	temp_pickup_bonus = 0.0
	run_words.clear()
	message = ""
