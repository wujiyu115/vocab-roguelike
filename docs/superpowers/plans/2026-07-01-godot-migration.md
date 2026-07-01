# 词域探险 Godot 4.7 迁移 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将词域探险从 C# WinForms 单文件应用完整迁移到 Godot 4.7（GDScript），支持 Windows/Android/iOS 三平台。

**Architecture:** 场景驱动架构，每个游戏实体（玩家、怪物、弹丸等）为独立场景。三个自动加载单例管理全局状态（GameManager）、词库（WordBank）和存档（SaveManager）。触控层为独立 CanvasLayer，按平台显隐。

**Tech Stack:** Godot 4.7 标准版、GDScript、Noto Sans CJK 字体

**Source reference:** 所有游戏逻辑对照 `WordRogue.cs`（3572 行），本计划中标注的行号均指该文件。

## Global Constraints

- Godot 4.7 标准版（非 Mono），仅使用 GDScript
- 逻辑分辨率 1280×720，stretch_mode=canvas_items，stretch_aspect=keep_height
- 移动端锁定横屏
- 字体使用 Noto Sans CJK（跨平台），不使用 Microsoft YaHei
- 所有精灵资源从现有项目 `assets/runtime/` 复制
- 词库从现有项目 `wordbank.json` 复制
- 用 `user://savegame.json` 存档（Godot 标准路径）
- Godot 项目创建在 `word_realm/` 子目录下（与现有 C# 项目共存）

---

## File Map

### 自动加载脚本
| File | Responsibility |
|---|---|
| `scripts/autoload/game_manager.gd` | 全局游戏状态、run 数据、状态切换信号 |
| `scripts/autoload/word_bank.gd` | 词库加载、选词算法、干扰词生成 |
| `scripts/autoload/save_manager.gd` | 存档读写、继续游戏状态、移动端后台存档 |

### 游戏逻辑脚本
| File | Responsibility |
|---|---|
| `scripts/game/game.gd` | 游戏主场景控制：房间流转、状态切换、输入分发 |
| `scripts/game/player.gd` | 玩家 CharacterBody2D：移动、冲刺、拾取、射击 |
| `scripts/game/monster.gd` | 怪物 CharacterBody2D：5 种 AI、碰撞伤害、弹幕 |
| `scripts/game/room_generator.gd` | 房间生成：障碍物放置、flood-fill 验证、怪物/词块/宝箱生成 |
| `scripts/game/projectile.gd` | 玩家弹丸 Area2D：飞行、碰撞检测 |
| `scripts/game/enemy_projectile.gd` | 敌方弹幕 Area2D |
| `scripts/game/meaning_token.gd` | 中文释义词块 Area2D：显示文字、发光效果 |
| `scripts/game/drop_item.gd` | 掉落道具 Area2D：自动拾取 |
| `scripts/game/chest.gd` | 宝箱 Area2D |
| `scripts/game/obstacle.gd` | 障碍物 StaticBody2D |
| `scripts/game/floating_text.gd` | 浮动文字 Label + Tween |

### UI 脚本
| File | Responsibility |
|---|---|
| `scripts/ui/main_menu.gd` | 主菜单：难度选择、开始/继续 |
| `scripts/ui/hud.gd` | HUD：血条、连击、消息、房间号 |
| `scripts/ui/touch_controls.gd` | 触控输入：点击移动、拖拽射击、交互/冲刺按钮 |
| `scripts/ui/reward_panel.gd` | 奖励卡选择面板 |
| `scripts/ui/pause_menu.gd` | 暂停菜单 |
| `scripts/ui/game_over_screen.gd` | 结算界面（Game Over / Win） |
| `scripts/ui/memory_book.gd` | 生词本 |

### 场景文件
| File | Root Node |
|---|---|
| `scenes/main.tscn` | Node（入口，加载菜单） |
| `scenes/menu/main_menu.tscn` | Control |
| `scenes/game/game.tscn` | Node2D |
| `scenes/game/player.tscn` | CharacterBody2D |
| `scenes/game/monster.tscn` | CharacterBody2D |
| `scenes/game/projectile.tscn` | Area2D |
| `scenes/game/enemy_projectile.tscn` | Area2D |
| `scenes/game/meaning_token.tscn` | Area2D |
| `scenes/game/drop_item.tscn` | Area2D |
| `scenes/game/chest.tscn` | Area2D |
| `scenes/game/obstacle.tscn` | StaticBody2D |
| `scenes/game/floating_text.tscn` | Label |
| `scenes/ui/hud.tscn` | CanvasLayer |
| `scenes/ui/touch_controls.tscn` | CanvasLayer |
| `scenes/ui/reward_panel.tscn` | Control |
| `scenes/ui/pause_menu.tscn` | Control |
| `scenes/ui/game_over_screen.tscn` | Control |
| `scenes/ui/memory_book.tscn` | Control |

---

### Task 1: 项目脚手架与自动加载单例

**Files:**
- Create: `word_realm/project.godot`
- Create: `word_realm/scripts/autoload/game_manager.gd`
- Create: `word_realm/scripts/autoload/word_bank.gd`
- Create: `word_realm/scripts/autoload/save_manager.gd`
- Create: `word_realm/scenes/main.tscn`
- Copy: `assets/runtime/*` → `word_realm/assets/sprites/` 和 `word_realm/assets/backgrounds/`
- Copy: `wordbank.json` → `word_realm/data/wordbank.json`

**Interfaces:**
- Produces: `GameManager` 单例 — 信号 `state_changed(new_state)`、属性 `current_state`、`room`、`combo`、`selected_mode`、`room_difficulty_scale`、玩家增益计数器
- Produces: `WordBank` 单例 — `load_words()`、`pick_room_words(count: int, max_difficulty: int) -> Array[Dictionary]`、`get_distractors(count, exclude) -> Array[Dictionary]`、`get_all_words() -> Array`
- Produces: `SaveManager` 单例 — `save_game()`、`load_game() -> Dictionary`、`save_continue_state(data: Dictionary)`、`has_continue() -> bool`、`clear_continue()`

- [ ] **Step 1: 创建 Godot 项目**

用 Godot 4.7 编辑器创建项目，或手动创建 `project.godot`：

```bash
mkdir -p word_realm/{assets/{sprites,backgrounds,fonts},data,scenes/{main,menu,game,ui},scripts/{autoload,game,ui},resources}
```

```ini
; word_realm/project.godot
[application]
config/name="词域探险 - Word Realm"
run/main_scene="res://scenes/main.tscn"
config/features=PackedStringArray("4.7")

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="keep_height"
window/handheld/orientation=4

[autoload]
GameManager="*res://scripts/autoload/game_manager.gd"
WordBank="*res://scripts/autoload/word_bank.gd"
SaveManager="*res://scripts/autoload/save_manager.gd"
```

- [ ] **Step 2: 复制资源文件**

```bash
cp assets/runtime/characters_monsters.png word_realm/assets/sprites/
cp assets/runtime/hero_gun_actions.png word_realm/assets/sprites/
cp assets/runtime/hero_directions.png word_realm/assets/sprites/
cp assets/runtime/hero_walk.png word_realm/assets/sprites/
cp assets/runtime/items_projectiles_chests.png word_realm/assets/sprites/
cp assets/runtime/theme_obstacles.png word_realm/assets/sprites/
cp assets/runtime/theme_tiles_walls.png word_realm/assets/sprites/
cp assets/runtime/weapon_ammo.png word_realm/assets/sprites/
cp assets/runtime/backgrounds/*.jpg word_realm/assets/backgrounds/
cp wordbank.json word_realm/data/wordbank.json
```

下载 Noto Sans CJK 字体放入 `word_realm/assets/fonts/`。

- [ ] **Step 3: 编写 GameManager**

对照 `WordRogue.cs:68-107`（枚举）和 `286-368`（GameForm 字段）。

```gdscript
# scripts/autoload/game_manager.gd
extends Node

signal state_changed(new_state: String)

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
```

- [ ] **Step 4: 编写 WordBank**

对照 `WordRogue.cs:1002-1039`（选词算法）和 `1041-1092`（生成释义词块）。

```gdscript
# scripts/autoload/word_bank.gd
extends Node

var all_words: Array[Dictionary] = []
var bank_words: Array[Dictionary] = []

func _ready():
	load_words()

func load_words() -> void:
	var file := FileAccess.open("res://data/wordbank.json", FileAccess.READ)
	if file == null:
		all_words = _default_words()
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		all_words = _default_words()
		return
	var data = json.data
	if data is Array:
		for entry in data:
			var word := {
				"word": entry.get("word", ""),
				"meaning": entry.get("meaning", ""),
				"difficulty": entry.get("difficulty", 1),
				"frequency_rank": entry.get("frequencyRank", 1000),
				"tags": entry.get("tags", []),
				"seen_count": 0,
				"correct_count": 0,
				"wrong_count": 0,
				"death_count": 0,
				"mastery": 0,
				"last_seen_room": 0,
			}
			all_words.append(word)
	if all_words.is_empty():
		all_words = _default_words()

func set_difficulty(max_difficulty: int) -> void:
	bank_words = all_words.filter(func(w): return w.difficulty <= max_difficulty)
	if bank_words.is_empty():
		bank_words = all_words.duplicate()

func pick_room_words(count: int) -> Array[Dictionary]:
	var selected: Array[Dictionary] = []
	var pool := bank_words.duplicate()
	var room := GameManager.room

	for i in range(count):
		if pool.is_empty():
			break
		var weights: Array[float] = []
		var total := 0.0
		for w in pool:
			var target_difficulty := 1.0 + room * 0.42
			var difficulty_score := 40.0 - absf(w.difficulty - target_difficulty) * 9.0
			var weight := maxf(6.0, difficulty_score)
			if w.seen_count == 0:
				weight += 30.0
			weight += w.wrong_count * 20.0
			weight += w.death_count * 50.0
			weight -= w.mastery * 8.0
			if room - w.last_seen_room <= 3 and w.last_seen_room > 0:
				weight -= 30.0
			if w.correct_count >= 3 and w.wrong_count == 0:
				weight -= 18.0
			weight = maxf(2.0, weight)
			total += weight
			weights.append(weight)

		var pick := randf() * total
		var acc := 0.0
		for j in range(pool.size()):
			acc += weights[j]
			if pick <= acc:
				selected.append(pool[j])
				pool.remove_at(j)
				break
	return selected

func get_distractors(count: int, exclude_meanings: Array[String]) -> Array[Dictionary]:
	var candidates := all_words.duplicate()
	candidates.shuffle()
	var result: Array[Dictionary] = []
	for w in candidates:
		if w.meaning in exclude_meanings:
			continue
		var share_tag := false
		for m in exclude_meanings:
			for aw in all_words:
				if aw.meaning == m and _share_tag(w, aw):
					share_tag = true
					break
			if share_tag:
				break
		if share_tag or randf() < 0.35:
			result.append(w)
			exclude_meanings.append(w.meaning)
			if result.size() >= count:
				break
	return result

func _share_tag(a: Dictionary, b: Dictionary) -> bool:
	if a.tags.is_empty() or b.tags.is_empty():
		return false
	for t in a.tags:
		if t in b.tags:
			return true
	return false

func merge_saved_stats(saved_words: Array) -> void:
	var saved_map := {}
	for w in saved_words:
		saved_map[w.get("word", "")] = w
	for w in all_words:
		if w.word in saved_map:
			var s = saved_map[w.word]
			w.seen_count = s.get("seen_count", s.get("seenCount", 0))
			w.correct_count = s.get("correct_count", s.get("correctCount", 0))
			w.wrong_count = s.get("wrong_count", s.get("wrongCount", 0))
			w.death_count = s.get("death_count", s.get("deathCount", 0))
			w.mastery = s.get("mastery", 0)
			w.last_seen_room = s.get("last_seen_room", s.get("lastSeenRoom", 0))

func _default_words() -> Array[Dictionary]:
	return [
		{"word": "increase", "meaning": "增加", "difficulty": 2, "frequency_rank": 1000, "tags": ["verb", "academic"], "seen_count": 0, "correct_count": 0, "wrong_count": 0, "death_count": 0, "mastery": 0, "last_seen_room": 0},
		{"word": "decrease", "meaning": "减少", "difficulty": 2, "frequency_rank": 1000, "tags": ["verb", "academic"], "seen_count": 0, "correct_count": 0, "wrong_count": 0, "death_count": 0, "mastery": 0, "last_seen_room": 0},
		{"word": "include", "meaning": "包含", "difficulty": 2, "frequency_rank": 1000, "tags": ["verb", "academic"], "seen_count": 0, "correct_count": 0, "wrong_count": 0, "death_count": 0, "mastery": 0, "last_seen_room": 0},
		{"word": "improve", "meaning": "改善", "difficulty": 2, "frequency_rank": 1000, "tags": ["verb", "daily"], "seen_count": 0, "correct_count": 0, "wrong_count": 0, "death_count": 0, "mastery": 0, "last_seen_room": 0},
		{"word": "affect", "meaning": "影响", "difficulty": 3, "frequency_rank": 1000, "tags": ["verb", "academic"], "seen_count": 0, "correct_count": 0, "wrong_count": 0, "death_count": 0, "mastery": 0, "last_seen_room": 0},
		{"word": "market", "meaning": "市场", "difficulty": 2, "frequency_rank": 1000, "tags": ["business", "noun"], "seen_count": 0, "correct_count": 0, "wrong_count": 0, "death_count": 0, "mastery": 0, "last_seen_room": 0},
		{"word": "research", "meaning": "研究", "difficulty": 3, "frequency_rank": 1000, "tags": ["academic", "noun"], "seen_count": 0, "correct_count": 0, "wrong_count": 0, "death_count": 0, "mastery": 0, "last_seen_room": 0},
		{"word": "transport", "meaning": "运输", "difficulty": 3, "frequency_rank": 1000, "tags": ["travel", "noun"], "seen_count": 0, "correct_count": 0, "wrong_count": 0, "death_count": 0, "mastery": 0, "last_seen_room": 0},
	]
```

- [ ] **Step 5: 编写 SaveManager**

对照 `WordRogue.cs:3461-3545`（存档读写）。

```gdscript
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
```

- [ ] **Step 6: 创建入口场景**

```gdscript
# scenes/main.tscn 的脚本（内联或外部）
extends Node

func _ready():
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
```

- [ ] **Step 7: 验证**

在 Godot 编辑器中打开 `word_realm/project.godot`，运行项目：
- 控制台无 GDScript 解析错误
- 自动加载单例注册成功（打印 `GameManager.is_mobile`、`WordBank.all_words.size()` 验证）
- 场景切换到 main_menu（此时场景为空白，不报错即可）

- [ ] **Step 8: 提交**

```bash
git add word_realm/
git commit -m "feat: scaffold Godot project with autoload singletons

GameManager (state, themes, run data), WordBank (word loading,
pick algorithm), SaveManager (save/load, mobile background save).
Copy sprite/background assets and wordbank."
```

---

### Task 2: 主菜单场景

**Files:**
- Create: `word_realm/scenes/menu/main_menu.tscn`
- Create: `word_realm/scripts/ui/main_menu.gd`

**Interfaces:**
- Consumes: `GameManager.change_state()`, `GameManager.selected_mode`, `WordBank.set_difficulty()`, `SaveManager.has_continue()`, `SaveManager.get_continue_state()`
- Produces: 完整可交互的主菜单 UI，点击开始/继续后切换到游戏场景

- [ ] **Step 1: 创建主菜单场景**

场景结构对照 `WordRogue.cs:2506-2649`（DrawMenu 系列方法）。

在 Godot 编辑器中创建 `main_menu.tscn`，节点树：

```
MainMenu (Control, full_rect)
├── Background (ColorRect, Color(18,22,28), full_rect)
├── Title (Label, "词域探险", 居中, y=78)
├── Subtitle (Label, "选择词库难度...", 居中, y=132)
├── DifficultyButtons (HBoxContainer, 居中, y=230)
│   ├── EasyButton (Button, "简单\n高中词汇")
│   ├── NormalButton (Button, "普通\n四六级词汇")
│   └── HardButton (Button, "困难\n雅思词汇")
├── StartButton (Button, "开始新游戏", 居中, y=420)
├── ContinueButton (Button, "继续游戏", 居中, y=492)
├── SelectedLabel (Label, "当前选择：简单/高中词汇", 居中, y=560)
└── HintLabel (Label, 操作提示, 居中, y=612)
```

- [ ] **Step 2: 编写主菜单脚本**

```gdscript
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
```

- [ ] **Step 3: 验证**

运行项目：
- 主菜单显示标题、三个难度按钮、开始按钮
- 点击难度按钮切换高亮，选中标签更新
- 键盘 1/2/3 选难度，Enter 开始（此时跳转到空游戏场景，不报错即可）
- 如有存档，继续按钮可见

- [ ] **Step 4: 提交**

```bash
git add word_realm/scenes/menu/ word_realm/scripts/ui/main_menu.gd
git commit -m "feat: add main menu with difficulty selection and continue"
```

---

### Task 3: 玩家角色场景

**Files:**
- Create: `word_realm/scenes/game/player.tscn`
- Create: `word_realm/scripts/game/player.gd`
- Create: `word_realm/scenes/game/game.tscn`（初始版本，仅放置玩家）
- Create: `word_realm/scripts/game/game.gd`（初始版本）

**Interfaces:**
- Consumes: `GameManager.is_mobile`, `GameManager.W`, `GameManager.H`
- Produces: `Player` 场景 — 属性 `hp`、`max_hp`、`speed`、`held_meaning`、方法 `try_dash()`、`try_interact(meanings, chests)`、`fire_held_meaning(aim_dir)`、`get_player_data() -> Dictionary`、信号 `fired(projectile_data)`、`picked_up(meaning)`、`interacted_chest(chest)`

- [ ] **Step 1: 创建 Player 场景**

`player.tscn` 节点树：

```
Player (CharacterBody2D)
├── CollisionShape2D (CircleShape2D, radius=18)
├── AnimatedSprite2D (SpriteFrames 从 hero_walk.png / hero_gun_actions.png)
├── PickupArea (Area2D)  # 拾取范围检测
│   └── CollisionShape2D (CircleShape2D, radius=84)
└── ShieldSprite (Sprite2D, 半透明圆环, visible=false)
```

- [ ] **Step 2: 编写 Player 脚本**

对照 `WordRogue.cs:158-178`（Player 类），`1578-1612`（UpdatePlayer），`1614-1630`（GetMoveInput/FacingVector），`1998-2011`（TryDash），`2013-2053`（TryInteract），`2079-2116`（FireHeldMeaning/GetAimDirection）。

```gdscript
# scripts/game/player.gd
extends CharacterBody2D

signal fired(data: Dictionary)
signal picked_up(meaning: String)
signal interacted_chest(chest: Node)

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var pickup_area: Area2D = $PickupArea
@onready var shield_sprite: Sprite2D = $ShieldSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var hp := 100.0
var max_hp := 100.0
var speed := 245.0
var dash_cooldown := 1.2
var dash_timer := 0.0
var throw_speed := 610.0
var pickup_range := 84.0
var defense := 0.0
var luck := 0.0
var invulnerable := 0.0
var speed_boost := 0.0
var shield_time := 0.0
var piercing_ink := false
var echo_scroll := false
var held_meaning := ""

var radius := 18.0
var facing := 0  # 0=down, 1=left, 2=right, 3=up
var last_move_dir := Vector2(0, 1)
var walk_anim_time := 0.0
var dash_anim_time := 0.0
var fire_anim_time := 0.0

# 移动端寻路目标
var move_target := Vector2.ZERO
var has_move_target := false

func _physics_process(delta: float) -> void:
	_update_timers(delta)
	var input := _get_move_input()
	if input.length() > 0.05:
		last_move_dir = input
		walk_anim_time += delta
		_update_facing_from_direction(input)
	else:
		walk_anim_time = 0.0
	var current_speed := speed
	if speed_boost > 0:
		current_speed *= 1.35
	velocity = input * current_speed
	move_and_slide()
	position = position.clamp(Vector2(48, 78), Vector2(GameManager.W - 48, GameManager.H - 48))
	_update_animation()
	shield_sprite.visible = shield_time > 0

func _update_timers(delta: float) -> void:
	if dash_timer > 0: dash_timer -= delta
	if invulnerable > 0: invulnerable -= delta
	if speed_boost > 0: speed_boost -= delta
	if shield_time > 0: shield_time -= delta
	if dash_anim_time > 0: dash_anim_time -= delta
	if fire_anim_time > 0: fire_anim_time -= delta

func _get_move_input() -> Vector2:
	if GameManager.is_mobile:
		return _get_mobile_move_input()
	var input := Vector2.ZERO
	if Input.is_action_pressed("move_up"): input.y -= 1
	if Input.is_action_pressed("move_down"): input.y += 1
	if Input.is_action_pressed("move_left"): input.x -= 1
	if Input.is_action_pressed("move_right"): input.x += 1
	return input.normalized()

func _get_mobile_move_input() -> Vector2:
	if not has_move_target:
		return Vector2.ZERO
	var to_target := move_target - position
	if to_target.length() < 8.0:
		has_move_target = false
		return Vector2.ZERO
	return to_target.normalized()

func set_move_target(target: Vector2) -> void:
	move_target = target
	has_move_target = true

func _update_facing_from_direction(dir: Vector2) -> void:
	if absf(dir.x) > absf(dir.y):
		facing = 1 if dir.x < 0 else 2
	else:
		facing = 3 if dir.y < 0 else 0

func _update_animation() -> void:
	var anim_name := "idle_down"
	var dir_names := ["down", "left", "right", "up"]
	if walk_anim_time > 0:
		anim_name = "walk_" + dir_names[facing]
	else:
		anim_name = "idle_" + dir_names[facing]
	if fire_anim_time > 0:
		anim_name = "fire_" + dir_names[facing]
	elif dash_anim_time > 0:
		anim_name = "dash_" + dir_names[facing]
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)

func try_dash() -> void:
	if dash_timer > 0:
		return
	var dir := _get_move_input()
	if dir.length() < 0.001:
		dir = last_move_dir
	if dir.length() < 0.001:
		dir = _facing_vector()
	position += dir * 128
	position = position.clamp(Vector2(48, 78), Vector2(GameManager.W - 48, GameManager.H - 48))
	dash_timer = dash_cooldown
	invulnerable = 0.28
	dash_anim_time = 0.22

func _facing_vector() -> Vector2:
	match facing:
		1: return Vector2(-1, 0)
		2: return Vector2(1, 0)
		3: return Vector2(0, -1)
		_: return Vector2(0, 1)

func try_interact(meanings: Array, chests: Array) -> void:
	var best: Node = null
	var best_dist := pickup_range
	for token in meanings:
		if not is_instance_valid(token):
			continue
		var d := position.distance_to(token.position)
		if d < best_dist:
			best = token
			best_dist = d
	if best != null:
		if held_meaning.length() > 0:
			drop_held_meaning(meanings)
		held_meaning = best.meaning
		picked_up.emit(held_meaning)
		best.queue_free()
		return
	for chest in chests:
		if not is_instance_valid(chest):
			continue
		if not chest.opened and position.distance_to(chest.position) < 70:
			chest.opened = true
			interacted_chest.emit(chest)
			return

func drop_held_meaning(_meanings: Array) -> void:
	if held_meaning.is_empty():
		return
	held_meaning = ""

func fire_held_meaning(aim_dir: Vector2, echo: bool = false) -> void:
	if held_meaning.is_empty() or aim_dir.length() < 0.001:
		return
	_update_facing_from_direction(aim_dir)
	var data := {
		"meaning": held_meaning,
		"position": position + aim_dir * 42 + Vector2(0, -8),
		"velocity": aim_dir * throw_speed,
		"piercing": piercing_ink,
		"universal": false,
	}
	fired.emit(data)
	fire_anim_time = 0.16
	if echo_scroll and not echo:
		var side := Vector2(-aim_dir.y, aim_dir.x)
		var echo_data := {
			"meaning": "回声",
			"position": position + aim_dir * 42 + Vector2(0, -8) + side * 11,
			"velocity": (aim_dir * 0.94 + side * 0.15).normalized() * (throw_speed * 0.95),
			"piercing": piercing_ink,
			"universal": true,
		}
		fired.emit(echo_data)
	held_meaning = ""

func take_damage(amount: float) -> void:
	if invulnerable > 0:
		return
	var actual := amount * (1.0 - defense)
	if shield_time > 0:
		actual *= 0.55
	hp -= actual
	invulnerable = 0.55

func get_player_data() -> Dictionary:
	return {
		"hp": hp, "max_hp": max_hp, "speed": speed,
		"dash_cooldown": dash_cooldown, "throw_speed": throw_speed,
		"pickup_range": pickup_range, "defense": defense, "luck": luck,
	}

func load_continue_state(data: Dictionary) -> void:
	hp = data.get("hp", 100.0)
	max_hp = data.get("max_hp", 100.0)
	speed = data.get("speed", 245.0)
	dash_cooldown = data.get("dash_cooldown", 1.2)
	throw_speed = data.get("throw_speed", 610.0)
	pickup_range = data.get("pickup_range", 84.0)
	defense = data.get("defense", 0.0)
	luck = data.get("luck", 0.0)
```

- [ ] **Step 3: 创建初始 Game 场景**

`game.tscn` 节点树（初始版本）：

```
Game (Node2D)
├── Background (Sprite2D, 房间背景)
├── Entities (Node2D)  # 游戏实体容器
│   └── Player (实例化 player.tscn)
├── HUD (CanvasLayer, 占位)
└── TouchControls (CanvasLayer, 占位)
```

```gdscript
# scripts/game/game.gd（初始版本）
extends Node2D

@onready var player: CharacterBody2D = $Entities/Player
@onready var background: Sprite2D = $Background

func _ready():
	player.position = Vector2(GameManager.W / 2, GameManager.H / 2 + 120)
	_load_background()

func _load_background() -> void:
	GameManager.room = 1
	var theme_index := GameManager.get_theme_index()
	var bg_name := GameManager.background_names[theme_index]
	var tex := load("res://assets/backgrounds/" + bg_name)
	if tex:
		background.texture = tex

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.is_mobile:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE: player.try_dash()
			KEY_E: player.try_interact([], [])
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var aim := (get_global_mouse_position() - player.position).normalized()
		player.fire_held_meaning(aim)
```

- [ ] **Step 4: 配置 Input Map**

在 `project.godot` 中添加输入动作：

```ini
[input]
move_up={deadzone: 0.2, events: [InputEventKey:W, InputEventKey:Up]}
move_down={deadzone: 0.2, events: [InputEventKey:S, InputEventKey:Down]}
move_left={deadzone: 0.2, events: [InputEventKey:A, InputEventKey:Left]}
move_right={deadzone: 0.2, events: [InputEventKey:D, InputEventKey:Right]}
dash={deadzone: 0.2, events: [InputEventKey:Space]}
interact={deadzone: 0.2, events: [InputEventKey:E]}
pause={deadzone: 0.2, events: [InputEventKey:Escape]}
toggle_book={deadzone: 0.2, events: [InputEventKey:Tab]}
```

- [ ] **Step 5: 验证**

运行项目 → 选难度 → 开始：
- 玩家角色出现在房间中央偏下
- WASD 移动流畅，受屏幕边界限制
- 空格冲刺（位移 128px，短暂无敌）
- 左键点击发射（此时无弹丸实体，但 `fired` 信号触发无报错）
- 背景图显示正确

- [ ] **Step 6: 提交**

```bash
git add word_realm/scenes/game/ word_realm/scripts/game/
git commit -m "feat: add player character with movement, dash, and input"
```

---

### Task 4: 房间生成系统

**Files:**
- Create: `word_realm/scripts/game/room_generator.gd`
- Create: `word_realm/scenes/game/obstacle.tscn`
- Create: `word_realm/scripts/game/obstacle.gd`
- Create: `word_realm/scenes/game/meaning_token.tscn`
- Create: `word_realm/scripts/game/meaning_token.gd`
- Create: `word_realm/scenes/game/chest.tscn`
- Create: `word_realm/scripts/game/chest.gd`
- Modify: `word_realm/scripts/game/game.gd`

**Interfaces:**
- Consumes: `GameManager.room`, `GameManager.get_theme_index()`, `WordBank.pick_room_words()`, `WordBank.get_distractors()`
- Produces: `RoomGenerator` — `generate_room(parent: Node2D) -> Dictionary` 返回 `{monsters: Array, meanings: Array, chests: Array, obstacles: Array}`
- Produces: `MeaningToken` 场景 — 属性 `meaning: String`、`correct_for_room: bool`，显示中文文字
- Produces: `Obstacle` 场景 — `StaticBody2D`，属性 `obstacle_kind: String`、`sprite_index: int`

- [ ] **Step 1: 创建 Obstacle 场景**

```
Obstacle (StaticBody2D)
├── CollisionShape2D (RectangleShape2D)
├── Sprite2D (图集切片或纯色矩形)
└── Shadow (Sprite2D, 半透明椭圆阴影)
```

```gdscript
# scripts/game/obstacle.gd
extends StaticBody2D

var obstacle_kind := ""
var sprite_index := 0
var bounds := Rect2()

func setup(kind: String, idx: int, rect: Rect2) -> void:
	obstacle_kind = kind
	sprite_index = idx
	bounds = rect
	position = rect.position + rect.size / 2
	var shape := RectangleShape2D.new()
	var inset := Vector2(minf(6.0, rect.size.x * 0.05), minf(6.0, rect.size.y * 0.05))
	shape.size = rect.size - inset * 2
	$CollisionShape2D.shape = shape
```

- [ ] **Step 2: 创建 MeaningToken 场景**

```
MeaningToken (Area2D)
├── CollisionShape2D (CircleShape2D, radius=20)
├── Label (中文释义文字)
└── Background (ColorRect, 半透明背景)
```

```gdscript
# scripts/game/meaning_token.gd
extends Area2D

var meaning := ""
var correct_for_room := false
var glow_timer := 0.0

@onready var label: Label = $Label

func setup(text: String, correct: bool) -> void:
	meaning = text
	correct_for_room = correct
	label.text = text

func _process(delta: float) -> void:
	glow_timer += delta
	var pulse := 0.8 + sin(glow_timer * 3.0) * 0.2
	modulate.a = pulse
```

- [ ] **Step 3: 创建 Chest 场景**

```
Chest (Area2D)
├── CollisionShape2D (CircleShape2D, radius=24)
├── Sprite2D
```

```gdscript
# scripts/game/chest.gd
extends Area2D

var opened := false

func open() -> void:
	opened = true
	modulate = Color(0.5, 0.5, 0.5)
```

- [ ] **Step 4: 编写 RoomGenerator**

对照 `WordRogue.cs:887-951`（StartRoom）、`1227-1398`（GenerateObstacles/CanPlaceObstacle/RoomNavigationIsValid）、`1041-1097`（SpawnMeaningTokens）。

```gdscript
# scripts/game/room_generator.gd
extends RefCounted

const OBSTACLE_SCENE := preload("res://scenes/game/obstacle.tscn")
const MEANING_TOKEN_SCENE := preload("res://scenes/game/meaning_token.tscn")
const CHEST_SCENE := preload("res://scenes/game/chest.tscn")

const W := 1280
const H := 720

var obstacles: Array[Rect2] = []

func generate_room(parent: Node2D, player_pos: Vector2) -> Dictionary:
	obstacles.clear()
	var result := {"obstacles": [], "meanings": [], "chests": [], "word_entries": []}

	# 障碍物生成
	var theme_index := GameManager.get_theme_index()
	var target := 6 + randi_range(0, 3) + mini(3, GameManager.room / 4)
	if theme_index == 7:
		target += 2
	for attempt in range(target * 18):
		if result.obstacles.size() >= target:
			break
		var obs_data := _create_random_obstacle(theme_index)
		if not _can_place_obstacle(obs_data, player_pos):
			continue
		obstacles.append(obs_data.bounds)
		if not _room_navigation_valid(player_pos):
			obstacles.pop_back()
			continue
		var obstacle := OBSTACLE_SCENE.instantiate()
		obstacle.setup(obs_data.kind, theme_index, obs_data.bounds)
		parent.add_child(obstacle)
		result.obstacles.append(obstacle)

	# 选词和生成怪物入口数据
	var room := GameManager.room
	var target_count := 3 + mini(3, room / 2)
	if GameManager.room_difficulty_scale > 1.15:
		target_count += 1
	if GameManager.selected_mode >= 4 and room > 3:
		target_count += 1
	if GameManager.selected_mode >= 6 and room > 5:
		target_count += 1
	target_count = mini(6, target_count)
	target_count = mini(target_count, maxi(1, WordBank.bank_words.size()))

	var chosen := WordBank.pick_room_words(target_count)
	result.word_entries = chosen

	# 生成释义词块
	var used_meanings: Array[String] = []
	for entry in chosen:
		var needed := _required_hits(entry)
		for i in range(needed):
			var token := MEANING_TOKEN_SCENE.instantiate()
			token.setup(entry.meaning, true)
			token.position = _random_free_position(20, player_pos)
			parent.add_child(token)
			result.meanings.append(token)
		used_meanings.append(entry.meaning)

	# 干扰词块
	var distractor_count := maxi(5, chosen.size() + 3)
	var distractors := WordBank.get_distractors(distractor_count, used_meanings)
	for d in distractors:
		var token := MEANING_TOKEN_SCENE.instantiate()
		token.setup(d.meaning, false)
		token.position = _random_free_position(20, player_pos)
		parent.add_child(token)
		result.meanings.append(token)

	# 宝箱
	if randf() < 0.52:
		var chest := CHEST_SCENE.instantiate()
		chest.position = _random_free_position(42, player_pos)
		parent.add_child(chest)
		result.chests.append(chest)

	return result

func _create_random_obstacle(theme_index: int) -> Dictionary:
	var width := 72.0 + randi_range(0, 70)
	var height := 44.0 + randi_range(0, 58)
	var kind := "障碍"
	# 对照 WordRogue.cs:1246-1330 各主题障碍物尺寸
	match theme_index:
		0: width = 46.0 + randi_range(0, 30); height = 46.0 + randi_range(0, 30); kind = "树木"
		1: width = 96.0 + randi_range(0, 54); height = 42.0 + randi_range(0, 32); kind = "办公桌"
		2: width = 54.0 + randi_range(0, 32); height = 118.0 + randi_range(0, 52); kind = "书架"
		3: width = 108.0 + randi_range(0, 54); height = 48.0 + randi_range(0, 34); kind = "实验桌"
		4: width = 70.0 + randi_range(0, 42); height = 78.0 + randi_range(0, 54); kind = "写字楼"
		5: width = 58.0 + randi_range(0, 34); height = 118.0 + randi_range(0, 54); kind = "书架"
		6: width = 96.0 + randi_range(0, 42); height = 48.0 + randi_range(0, 24); kind = "汽车"
		7: width = 40.0 + randi_range(0, 34); height = 34.0 + randi_range(0, 30); kind = "花草"

	var x := 72.0 + randi_range(0, maxi(1, int(W - 144 - width)))
	var y := 98.0 + randi_range(0, maxi(1, int(H - 170 - height)))
	return {"bounds": Rect2(x, y, width, height), "kind": kind}

func _can_place_obstacle(data: Dictionary, player_pos: Vector2) -> bool:
	var r: Rect2 = data.bounds
	var padded := r.grow(30)
	if padded.position.y < 78 or padded.position.x < 42:
		return false
	if padded.end.x > W - 42 or padded.end.y > H - 48:
		return false
	if padded.has_point(player_pos):
		return false
	if _distance_point_to_rect(player_pos, r) < 150:
		return false
	var start_area := Rect2(W / 2.0 - 95, H / 2.0 + 95, 190, 150)
	var center_area := Rect2(W / 2.0 - 100, H / 2.0 - 80, 200, 160)
	if r.intersects(start_area) or r.intersects(center_area):
		return false
	for existing in obstacles:
		if padded.intersects(existing):
			return false
	return true

func _room_navigation_valid(player_pos: Vector2) -> bool:
	# 对照 WordRogue.cs:1351-1398 flood-fill 验证
	const CELL := 40
	var cols := (W - 96) / CELL
	var rows := (H - 140) / CELL
	var blocked := {}
	var total_walkable := 0
	var start := Vector2i(-1, -1)
	var start_dist := 999999.0

	for x in range(cols):
		for y in range(rows):
			var center := Vector2(48 + x * CELL + CELL / 2, 82 + y * CELL + CELL / 2)
			var is_blocked := _is_point_blocked(center, 18)
			blocked[Vector2i(x, y)] = is_blocked
			if not is_blocked:
				total_walkable += 1
				var dist := center.distance_to(player_pos)
				if dist < start_dist:
					start_dist = dist
					start = Vector2i(x, y)

	if total_walkable < cols * rows * 0.62 or start.x < 0:
		return false

	var seen := {}
	var queue: Array[Vector2i] = [start]
	seen[start] = true
	var visited := 0
	while not queue.is_empty():
		var p := queue.pop_front()
		visited += 1
		for offset in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var n := p + offset
			if n.x < 0 or n.y < 0 or n.x >= cols or n.y >= rows:
				continue
			if blocked.get(n, true) or seen.get(n, false):
				continue
			seen[n] = true
			queue.append(n)

	return visited >= total_walkable * 0.9

func _is_point_blocked(center: Vector2, radius: float) -> bool:
	if center.x - radius < 34 or center.x + radius > W - 34:
		return true
	if center.y - radius < 66 or center.y + radius > H - 34:
		return true
	for obs_rect in obstacles:
		if _circle_intersects_rect(center, radius, obs_rect):
			return true
	return false

func _circle_intersects_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	var closest_x := clampf(center.x, rect.position.x, rect.end.x)
	var closest_y := clampf(center.y, rect.position.y, rect.end.y)
	var dx := center.x - closest_x
	var dy := center.y - closest_y
	return dx * dx + dy * dy <= radius * radius

func _distance_point_to_rect(point: Vector2, rect: Rect2) -> float:
	var dx := maxf(maxf(rect.position.x - point.x, 0), point.x - rect.end.x)
	var dy := maxf(maxf(rect.position.y - point.y, 0), point.y - rect.end.y)
	return sqrt(dx * dx + dy * dy)

func _random_free_position(radius: float, player_pos: Vector2) -> Vector2:
	for attempt in range(80):
		var p := Vector2(100 + randi_range(0, W - 200), 110 + randi_range(0, H - 210))
		if p.distance_to(player_pos) < 130:
			continue
		if _is_point_blocked(p, radius):
			continue
		return p
	# 网格回退
	for x in range(90, W - 90, 44):
		for y in range(110, H - 80, 44):
			var p := Vector2(x, y)
			if not _is_point_blocked(p, radius) and p.distance_to(player_pos) >= 90:
				return p
	return player_pos

func _required_hits(entry: Dictionary) -> int:
	var max_hp := 2.0 if (GameManager.room > 4 or entry.difficulty >= 4) else 1.0
	var needed := ceili(max_hp)
	if entry.get("shield", false):
		needed += 1
	return maxi(1, needed)
```

- [ ] **Step 5: 更新 game.gd 集成房间生成**

```gdscript
# game.gd 中增加房间生成调用
var room_generator := RoomGenerator.new()
var current_meanings: Array = []
var current_chests: Array = []

func _ready():
	player.position = Vector2(GameManager.W / 2, GameManager.H / 2 + 120)
	_start_room()

func _start_room() -> void:
	GameManager.room += 1
	_load_background()
	_clear_entities()
	var result := room_generator.generate_room($Entities, player.position)
	current_meanings = result.meanings
	current_chests = result.chests
	GameManager.message = "第 %d 间：%s" % [GameManager.room, GameManager.get_current_theme().name]
```

- [ ] **Step 6: 验证**

运行项目 → 进入游戏：
- 房间显示背景图
- 障碍物随机分布，不堵死路径
- 中文释义词块散落在地面，显示文字
- 宝箱有概率出现

- [ ] **Step 7: 提交**

```bash
git add word_realm/scenes/game/ word_realm/scripts/game/
git commit -m "feat: add room generation with obstacles, meaning tokens, and chests"
```

---

### Task 5: 怪物系统

**Files:**
- Create: `word_realm/scenes/game/monster.tscn`
- Create: `word_realm/scripts/game/monster.gd`
- Create: `word_realm/scenes/game/enemy_projectile.tscn`
- Create: `word_realm/scripts/game/enemy_projectile.gd`
- Modify: `word_realm/scripts/game/room_generator.gd`（添加怪物生成）
- Modify: `word_realm/scripts/game/game.gd`（怪物碰撞伤害处理）

**Interfaces:**
- Consumes: `GameManager.room`, `GameManager.room_difficulty_scale`, player position
- Produces: `Monster` 场景 — 属性 `entry: Dictionary`、`kind: int`、`hp`、`shield_up`，信号 `died(monster)`、`shot(bullet_data)`

- [ ] **Step 1: 创建 Monster 场景**

```
Monster (CharacterBody2D)
├── CollisionShape2D (CircleShape2D)
├── Sprite2D (怪物图集切片)
├── WordLabel (Label, 显示英文单词)
├── HpBar (ProgressBar, 精英怪血条)
├── ShieldSprite (Sprite2D, 护盾, visible=false)
└── HitArea (Area2D)  # 被弹丸命中检测
    └── CollisionShape2D (CircleShape2D)
```

- [ ] **Step 2: 编写 Monster 脚本**

对照 `WordRogue.cs:180-196`（Monster 类）、`1646-1726`（UpdateMonsters AI）、`1729-1751`（射击/精英判定）。

```gdscript
# scripts/game/monster.gd
extends CharacterBody2D

signal died(monster: Node)
signal shot(data: Dictionary)

@onready var sprite: Sprite2D = $Sprite2D
@onready var word_label: Label = $WordLabel
@onready var hp_bar: ProgressBar = $HpBar
@onready var shield_sprite: Sprite2D = $ShieldSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var entry: Dictionary = {}
var kind: int = GameManager.MonsterKind.WANDERER
var hp := 1.0
var max_hp := 1.0
var radius := 31.0
var think_timer := 0.0
var rage_timer := 0.0
var dash_windup := 0.0
var shoot_timer := 2.0
var shield_up := false
var from_mistake := false
var move_dir := Vector2.ZERO

func setup(word_entry: Dictionary, monster_kind: int, pos: Vector2) -> void:
	entry = word_entry
	kind = monster_kind
	position = pos
	radius = 31 + entry.difficulty * 1.8
	max_hp = 2.0 if (GameManager.room > 4 or entry.difficulty >= 4) else 1.0
	hp = max_hp
	shield_up = (kind == GameManager.MonsterKind.SHIELD)
	from_mistake = entry.wrong_count > entry.correct_count and randf() < 0.35
	if from_mistake:
		kind = GameManager.MonsterKind.GHOST

	var shape := CircleShape2D.new()
	shape.radius = radius
	collision_shape.shape = shape
	$HitArea/CollisionShape2D.shape = shape.duplicate()

	word_label.text = entry.word
	think_timer = randf() * 1.2
	shoot_timer = 1.4 + randf() * 2.3
	hp_bar.visible = max_hp >= 2

func _physics_process(delta: float) -> void:
	if rage_timer > 0:
		rage_timer -= delta
	var player := _get_player()
	if player == null:
		return
	var speed := 55.0 + GameManager.room * 3 + entry.difficulty * 8.0
	if kind == GameManager.MonsterKind.CHASER: speed += 28
	if kind == GameManager.MonsterKind.GHOST: speed += 38
	if rage_timer > 0: speed *= 1.8
	if GameManager.room_difficulty_scale < 0.95: speed *= 0.85
	if GameManager.room_difficulty_scale > 1.1: speed *= 1.12

	var to_player := (player.position - position).normalized()

	match kind:
		GameManager.MonsterKind.WANDERER, GameManager.MonsterKind.SHIELD:
			think_timer -= delta
			if think_timer <= 0:
				var angle := randf() * TAU
				move_dir = Vector2(cos(angle), sin(angle))
				think_timer = 0.8 + randf() * 1.4
			if position.distance_to(player.position) < 180:
				move_dir = (move_dir * 0.75 + to_player * 0.25).normalized()
		GameManager.MonsterKind.CHASER, GameManager.MonsterKind.GHOST:
			move_dir = (move_dir * 0.82 + to_player * 0.18).normalized()
		GameManager.MonsterKind.DASHER:
			if dash_windup > 0:
				dash_windup -= delta
				if dash_windup <= 0:
					move_dir = to_player * 4.2
			else:
				think_timer -= delta
				move_dir *= 0.94
				if think_timer <= 0 and position.distance_to(player.position) < 360:
					dash_windup = 0.55
					think_timer = 2.2
				elif move_dir.length() < 0.1:
					move_dir = to_player * 0.45

	velocity = move_dir * speed
	move_and_slide()
	sprite.flip_h = velocity.x < -0.05
	position = position.clamp(Vector2(48, 82), Vector2(GameManager.W - 48, GameManager.H - 52))

	# 碰撞伤害 — 由 game.gd 在 _physics_process 中检测
	# 精英射击
	_update_shooting(delta, player)
	# 更新视觉
	_update_visuals()

func _update_shooting(delta: float, player: Node2D) -> void:
	if not _is_elite():
		return
	shoot_timer -= delta
	var dist := position.distance_to(player.position)
	if shoot_timer > 0 or dist > 520 or dist < 70:
		return
	var dir := (player.position - position).normalized()
	var bullet_speed := 210.0 + GameManager.room * 8 + entry.difficulty * 12.0
	var data := {
		"position": position + dir * (radius + 12),
		"velocity": dir * bullet_speed,
		"damage": 9.0 + entry.difficulty * 1.6,
	}
	shot.emit(data)
	shoot_timer = maxf(1.25, 3.3 - GameManager.room * 0.08 - entry.difficulty * 0.08)

func _is_elite() -> bool:
	return max_hp >= 2 or kind == GameManager.MonsterKind.SHIELD or entry.difficulty >= 5

func take_hit(meaning: String, universal: bool) -> Dictionary:
	# 对照 WordRogue.cs:1866-1919 ResolveHit
	var correct := universal or meaning == entry.meaning
	if correct:
		GameManager.correct_hits += 1
		SaveManager.save_data.total_correct += 1
		if not universal:
			entry.correct_count += 1
			entry.mastery = mini(10, entry.mastery + 1)
		GameManager.combo += 1
		GameManager.streak_wrong = 0

		if shield_up:
			shield_up = false
			rage_timer = 0.6
			return {"hit": true, "killed": false, "correct": true, "shield_break": true}

		var damage := max_hp if max_hp < 2 else 1.0
		if GameManager.combo >= 3:
			damage += 1
		hp -= damage
		var killed := hp <= 0
		if killed:
			died.emit(self)
		return {"hit": true, "killed": killed, "correct": true, "shield_break": false, "damage": damage}
	else:
		GameManager.wrong_hits += 1
		SaveManager.save_data.total_wrong += 1
		entry.wrong_count += 1
		entry.mastery = maxi(0, entry.mastery - 1)
		GameManager.combo = 0
		GameManager.streak_wrong += 1
		rage_timer = 3.0
		hp -= 0.15
		if GameManager.streak_wrong >= 2:
			GameManager.room_difficulty_scale += 0.08
			GameManager.streak_wrong = 0
		return {"hit": true, "killed": false, "correct": false}

func _update_visuals() -> void:
	shield_sprite.visible = shield_up
	if max_hp >= 2:
		hp_bar.value = hp / max_hp
	if rage_timer > 0:
		modulate = Color(1.5, 0.6, 0.6) if fmod(rage_timer, 0.3) < 0.15 else Color.WHITE
	else:
		modulate = Color.WHITE

func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if not players.is_empty() else null
```

- [ ] **Step 3: 创建 EnemyProjectile 场景**

```gdscript
# scripts/game/enemy_projectile.gd
extends Area2D

var vel := Vector2.ZERO
var life := 3.2
var damage := 10.0

func setup(data: Dictionary) -> void:
	position = data.position
	vel = data.velocity
	life = 3.2
	damage = data.damage

func _physics_process(delta: float) -> void:
	position += vel * delta
	life -= delta
	if life <= 0 or position.x < -30 or position.x > GameManager.W + 30 or position.y < -30 or position.y > GameManager.H + 30:
		queue_free()
```

- [ ] **Step 4: 更新 RoomGenerator 添加怪物生成**

在 `generate_room()` 末尾增加怪物生成逻辑，对照 `WordRogue.cs:919-939`。

```gdscript
# room_generator.gd generate_room() 中追加：
const MONSTER_SCENE := preload("res://scenes/game/monster.tscn")

# 在选词之后：
for entry in chosen:
	entry.seen_count += 1
	entry.last_seen_room = GameManager.room
	var monster := MONSTER_SCENE.instantiate()
	var kind := _pick_monster_kind(entry)
	monster.setup(entry, kind, _random_free_position(monster.radius + 8, player_pos))
	parent.add_child(monster)
	result.monsters.append(monster)

func _pick_monster_kind(entry: Dictionary) -> int:
	var roll := randi_range(0, 99)
	var tier := GameManager.room + entry.difficulty
	if tier > 8 and roll < 18: return GameManager.MonsterKind.SHIELD
	if tier > 6 and roll < 38: return GameManager.MonsterKind.DASHER
	if tier > 4 and roll < 68: return GameManager.MonsterKind.CHASER
	return GameManager.MonsterKind.WANDERER
```

- [ ] **Step 5: 更新 game.gd 处理怪物碰撞和弹幕**

```gdscript
# game.gd 中增加：
const ENEMY_PROJECTILE_SCENE := preload("res://scenes/game/enemy_projectile.tscn")

var current_monsters: Array = []

func _start_room() -> void:
	# ... 之前的代码 ...
	current_monsters = result.monsters
	for monster in current_monsters:
		monster.died.connect(_on_monster_died)
		monster.shot.connect(_on_monster_shot)

func _physics_process(delta: float) -> void:
	if GameManager.current_state != GameManager.State.PLAYING:
		return
	_check_monster_collisions()
	_check_enemy_projectile_hits()

func _check_monster_collisions() -> void:
	for monster in current_monsters:
		if not is_instance_valid(monster):
			continue
		var dist := player.position.distance_to(monster.position)
		if dist < monster.radius + player.radius and player.invulnerable <= 0:
			var damage := 12.0 + monster.entry.difficulty * 1.8
			player.take_damage(damage)
			GameManager.collisions += 1
			var push := (player.position - monster.position).normalized()
			if push.length() < 0.001: push = Vector2(1, 0)
			player.position += push * 34

func _on_monster_died(monster: Node) -> void:
	current_monsters.erase(monster)
	monster.queue_free()
	if current_monsters.is_empty():
		_on_room_cleared()

func _on_monster_shot(data: Dictionary) -> void:
	var bullet := ENEMY_PROJECTILE_SCENE.instantiate()
	bullet.setup(data)
	$Entities.add_child(bullet)
```

- [ ] **Step 6: 验证**

运行项目 → 进入游戏：
- 怪物出现在房间中，显示英文单词
- Wanderer 随机游走，Chaser 追踪玩家
- 怪物碰到玩家扣血
- 精英怪发射弹幕

- [ ] **Step 7: 提交**

```bash
git add word_realm/scenes/game/ word_realm/scripts/game/
git commit -m "feat: add monster system with 5 AI types and enemy projectiles"
```

---

### Task 6: 弹丸与词汇匹配核心玩法

**Files:**
- Create: `word_realm/scenes/game/projectile.tscn`
- Create: `word_realm/scripts/game/projectile.gd`
- Create: `word_realm/scenes/game/floating_text.tscn`
- Create: `word_realm/scripts/game/floating_text.gd`
- Modify: `word_realm/scripts/game/game.gd`（连接射击、命中判定、浮动文字）

**Interfaces:**
- Consumes: `Player.fired` 信号, `Monster.take_hit()`
- Produces: `Projectile` 场景 — Area2D，碰撞怪物时触发匹配判定
- Produces: `FloatingText` 场景 — 漂浮文字效果
- Produces: `game.gd` 中完整的 射击→命中→反馈 闭环

- [ ] **Step 1: 创建 Projectile 场景**

```
Projectile (Area2D)
├── CollisionShape2D (CircleShape2D, radius=9)
├── Sprite2D (弹丸图集)
└── Label (显示中文释义)
```

```gdscript
# scripts/game/projectile.gd
extends Area2D

var meaning := ""
var vel := Vector2.ZERO
var life := 1.55
var piercing := false
var universal := false
var return_on_miss := true
var hit_monsters: Array[Node] = []

func setup(data: Dictionary) -> void:
	meaning = data.meaning
	position = data.position
	vel = data.velocity
	piercing = data.get("piercing", false)
	universal = data.get("universal", false)
	life = 1.55
	return_on_miss = not universal
	$Label.text = meaning if not universal else "回声"

func _physics_process(delta: float) -> void:
	position += vel * delta
	life -= delta
	if life <= 0 or position.x < -40 or position.x > GameManager.W + 40 or position.y < -40 or position.y > GameManager.H + 40:
		_on_expired()
		queue_free()
```

- [ ] **Step 2: 创建 FloatingText 场景**

```gdscript
# scripts/game/floating_text.gd
extends Label

func show_text(text: String, pos: Vector2, color: Color) -> void:
	self.text = text
	position = pos
	modulate = color
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 32, 1.35)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 1.35)
	tween.tween_callback(queue_free)
```

- [ ] **Step 3: 更新 game.gd 连接弹丸系统**

对照 `WordRogue.cs:1753-1798`（UpdateProjectiles）和 `1866-1919`（ResolveHit）。

```gdscript
# game.gd 中增加：
const PROJECTILE_SCENE := preload("res://scenes/game/projectile.tscn")
const FLOATING_TEXT_SCENE := preload("res://scenes/game/floating_text.tscn")

func _ready():
	player.add_to_group("player")
	player.fired.connect(_on_player_fired)
	player.picked_up.connect(_on_player_picked_up)
	player.interacted_chest.connect(_on_chest_opened)
	# ...

func _on_player_fired(data: Dictionary) -> void:
	var proj := PROJECTILE_SCENE.instantiate()
	proj.setup(data)
	proj.area_entered.connect(_on_projectile_hit.bind(proj))
	$Entities.add_child(proj)

func _on_projectile_hit(area: Area2D, proj: Node) -> void:
	# 检查是否是怪物的 HitArea
	var monster := area.get_parent()
	if not monster is CharacterBody2D or not monster.has_method("take_hit"):
		return
	if monster in proj.hit_monsters:
		return
	proj.hit_monsters.append(monster)

	var result := monster.take_hit(proj.meaning, proj.universal)
	if result.correct:
		if result.get("shield_break", false):
			_add_float("破盾" if not proj.universal else "回声破盾", monster.position + Vector2(0, -36), Color(0.478, 0.827, 1.0))
		elif result.get("killed", false):
			_add_float("记住 " + monster.entry.word, monster.position + Vector2(0, -58), Color.WHITE)
			_try_drop(monster)
		else:
			_add_float("正确：" + monster.entry.meaning if not proj.universal else "回声命中", monster.position + Vector2(0, -38), Color(0.596, 0.961, 0.706))

		if GameManager.combo >= 3:
			player.hp = minf(player.max_hp, player.hp + 4)
			_add_float("连击+" + str(GameManager.combo), player.position + Vector2(0, -34), Color(0.580, 1.0, 0.651))

		proj.return_on_miss = false
		if not proj.piercing:
			proj.queue_free()
	else:
		_add_float("错配！%s = %s" % [monster.entry.word, monster.entry.meaning], monster.position + Vector2(0, -38), Color(1.0, 0.824, 0.369))
		if GameManager.streak_wrong == 0:
			_add_float("房间躁动", Vector2(GameManager.W / 2 - 40, 120), Color(1.0, 0.510, 0.510))
		# 返还词块
		_return_meaning(proj.meaning)
		proj.queue_free()

func _add_float(text: String, pos: Vector2, color: Color) -> void:
	var ft := FLOATING_TEXT_SCENE.instantiate()
	ft.show_text(text, pos, color)
	$Entities.add_child(ft)

func _return_meaning(meaning: String) -> void:
	if meaning.is_empty() or current_monsters.is_empty():
		return
	var correct := current_monsters.any(func(m): return is_instance_valid(m) and m.entry.meaning == meaning)
	var token := MEANING_TOKEN_SCENE.instantiate()
	token.setup(meaning, correct)
	token.position = room_generator._random_free_position(20, player.position)
	$Entities.add_child(token)
	current_meanings.append(token)

func _on_player_picked_up(meaning: String) -> void:
	_add_float("拾取：" + meaning, player.position + Vector2(0, -30), Color(0.918, 0.937, 0.612))
```

- [ ] **Step 4: 验证**

运行项目 → 完整游戏循环测试：
- E 键拾取地面词块
- 鼠标左键朝怪物射击
- 匹配正确 → 怪物受伤/死亡 + 绿色浮动文字
- 匹配错误 → 怪物狂暴变红 + 黄色浮动文字 + 词块返还
- 连击 >= 3 → 额外伤害 + 回血
- 所有怪物清除 → 进入下一间

- [ ] **Step 5: 提交**

```bash
git add word_realm/
git commit -m "feat: add projectile system and word matching core gameplay"
```

---

### Task 7: 道具、掉落与奖励卡系统

**Files:**
- Create: `word_realm/scenes/game/drop_item.tscn`
- Create: `word_realm/scripts/game/drop_item.gd`
- Create: `word_realm/scenes/ui/reward_panel.tscn`
- Create: `word_realm/scripts/ui/reward_panel.gd`
- Modify: `word_realm/scripts/game/game.gd`（掉落、宝箱、奖励卡、房间流转完整逻辑）

**Interfaces:**
- Consumes: `Monster.died`, `Player.interacted_chest`
- Produces: `DropItem` 场景 — 走近自动拾取
- Produces: `RewardPanel` — 信号 `reward_chosen(card: Dictionary)`

- [ ] **Step 1: 创建 DropItem 场景**

```gdscript
# scripts/game/drop_item.gd
extends Area2D

var kind: int = GameManager.DropKind.APPLE
var life := 16.0

@onready var label: Label = $Label

const DROP_NAMES := {
	GameManager.DropKind.APPLE: "苹果",
	GameManager.DropKind.COFFEE: "咖啡",
	GameManager.DropKind.SHIELD_POTION: "护盾",
	GameManager.DropKind.INK: "穿透墨水",
	GameManager.DropKind.BOOTS: "风之靴",
	GameManager.DropKind.FEATHER: "轻羽",
	GameManager.DropKind.GLOVES: "磁力手套",
}

func setup(drop_kind: int, pos: Vector2) -> void:
	kind = drop_kind
	position = pos
	label.text = DROP_NAMES.get(kind, "道具")

func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0:
		queue_free()
```

- [ ] **Step 2: 编写 RewardPanel**

对照 `WordRogue.cs:2259-2376`（PrepareRewardCards/ChooseReward/ApplyReward）。

```gdscript
# scripts/ui/reward_panel.gd
extends Control

signal reward_chosen(card: Dictionary)

var cards: Array[Dictionary] = []

func show_rewards() -> void:
	cards = _prepare_cards()
	visible = true
	_update_display()

func _prepare_cards() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var hp_pct := 0.2 + randf() * 0.3
	result.append({"kind": GameManager.RewardKind.SURVIVAL, "category": "生存类", "title": "生命补给", "description": "最大生命和当前生命 +%d%%" % roundi(hp_pct * 100), "value": hp_pct})

	if randf() < 0.5:
		result.append({"kind": GameManager.RewardKind.MOVE_SPEED, "category": "防御类", "title": "机动步伐", "description": "移动速度永久 +14", "value": 14.0})
	else:
		result.append({"kind": GameManager.RewardKind.SHIELD, "category": "防御类", "title": "能量护盾", "description": "减伤提升并获得护盾", "value": 0.06})

	var item := randi_range(0, 2)
	match item:
		0: result.append({"kind": GameManager.RewardKind.CHEST_SPEED, "category": "道具类", "title": "风箱补给", "description": "获得宝箱移速道具 3间", "value": 22.0})
		1: result.append({"kind": GameManager.RewardKind.CHEST_THROW, "category": "道具类", "title": "弹药校准", "description": "获得宝箱弹速道具 3间", "value": 90.0})
		2: result.append({"kind": GameManager.RewardKind.CHEST_ECHO, "category": "道具类", "title": "回声卷轴", "description": "获得回声卷轴 3间", "value": 0.0})
	return result

func _update_display() -> void:
	for i in range(mini(3, cards.size())):
		var btn: Button = get_node("Card%d" % (i + 1))
		btn.text = "%s\n%s\n%s" % [cards[i].title, cards[i].category, cards[i].description]
		if not btn.pressed.is_connected(_on_card_chosen):
			btn.pressed.connect(_on_card_chosen.bind(i))

func _on_card_chosen(index: int) -> void:
	reward_chosen.emit(cards[index])
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: _on_card_chosen(0)
			KEY_2: if cards.size() > 1: _on_card_chosen(1)
			KEY_3: if cards.size() > 2: _on_card_chosen(2)
```

- [ ] **Step 3: 更新 game.gd — 掉落、宝箱、奖励卡、限时增益、房间流转**

对照 `WordRogue.cs:2124-2257`（ApplyDrop/OpenChest/Grant*）、`2378-2411`（OnRoomCleared）、`952-990`（AdvanceRoomLimitedPowerups）。

```gdscript
# game.gd 中增加：

func _try_drop(monster: Node) -> void:
	if randf() < 0.16 + player.luck:
		var kind := randi_range(0, 6) as GameManager.DropKind
		if current_monsters.size() <= 1:
			_apply_drop(kind)
			_add_float("自动拾取：" + DropItem.DROP_NAMES.get(kind, "道具"), monster.position + Vector2(-26, -30), Color(1.0, 0.886, 0.459))
		else:
			var drop := DROP_ITEM_SCENE.instantiate()
			drop.setup(kind, monster.position)
			drop.body_entered.connect(_on_drop_collected.bind(drop))
			$Entities.add_child(drop)

func _on_drop_collected(body: Node, drop: Node) -> void:
	if body == player:
		_apply_drop(drop.kind)
		drop.queue_free()

func _apply_drop(kind: int) -> void:
	match kind:
		GameManager.DropKind.APPLE:
			player.hp = minf(player.max_hp, player.hp + player.max_hp * 0.3)
			_add_float("苹果 +HP", player.position + Vector2(0, -30), Color(0.627, 1.0, 0.682))
		GameManager.DropKind.COFFEE:
			player.speed_boost = 7.0
			_add_float("咖啡 加速", player.position + Vector2(0, -30), Color(0.918, 0.753, 0.494))
		GameManager.DropKind.SHIELD_POTION:
			player.shield_time = 10.0
			_add_float("护盾 10s", player.position + Vector2(0, -30), Color(0.486, 0.804, 1.0))
		GameManager.DropKind.INK:
			player.piercing_ink = true
			GameManager.piercing_ink_rooms = 3
			_add_float("穿透墨水 3间", player.position + Vector2(-30, -42), Color(0.737, 0.694, 1.0))
		GameManager.DropKind.BOOTS:
			_grant_speed_bonus(18.0, "风之靴 3间")
		GameManager.DropKind.FEATHER:
			_grant_dash_bonus(0.12, "轻羽 3间")
		GameManager.DropKind.GLOVES:
			_grant_pickup_bonus(18.0, "磁力手套 3间")

func _grant_speed_bonus(amount: float, label: String) -> void:
	if GameManager.temp_speed_bonus <= 0:
		player.speed += amount
		GameManager.temp_speed_bonus = amount
	elif amount > GameManager.temp_speed_bonus:
		player.speed += amount - GameManager.temp_speed_bonus
		GameManager.temp_speed_bonus = amount
	GameManager.speed_boost_rooms = 3
	_add_float(label, player.position + Vector2(-30, -42), Color(0.624, 0.882, 1.0))

func _grant_throw_bonus(amount: float, label: String) -> void:
	if GameManager.temp_throw_bonus <= 0:
		player.throw_speed += amount
		GameManager.temp_throw_bonus = amount
	elif amount > GameManager.temp_throw_bonus:
		player.throw_speed += amount - GameManager.temp_throw_bonus
		GameManager.temp_throw_bonus = amount
	GameManager.throw_boost_rooms = 3
	_add_float(label, player.position + Vector2(-30, -42), Color(1.0, 0.886, 0.459))

func _grant_dash_bonus(amount: float, label: String) -> void:
	if GameManager.temp_dash_bonus <= 0:
		player.dash_cooldown = maxf(0.55, player.dash_cooldown - amount)
		GameManager.temp_dash_bonus = amount
	elif amount > GameManager.temp_dash_bonus:
		player.dash_cooldown = maxf(0.55, player.dash_cooldown - (amount - GameManager.temp_dash_bonus))
		GameManager.temp_dash_bonus = amount
	GameManager.dash_boost_rooms = 3
	_add_float(label, player.position + Vector2(-30, -42), Color(0.961, 0.961, 0.824))

func _grant_pickup_bonus(amount: float, label: String) -> void:
	if GameManager.temp_pickup_bonus <= 0:
		player.pickup_range += amount
		GameManager.temp_pickup_bonus = amount
	elif amount > GameManager.temp_pickup_bonus:
		player.pickup_range += amount - GameManager.temp_pickup_bonus
		GameManager.temp_pickup_bonus = amount
	GameManager.pickup_boost_rooms = 3
	_add_float(label, player.position + Vector2(-30, -42), Color(1.0, 0.780, 0.471))

func _on_chest_opened(chest: Node) -> void:
	var choice := randi_range(0, 2)
	match choice:
		0: _grant_speed_bonus(22.0, "宝箱：移速 3间")
		1: _grant_throw_bonus(90.0, "宝箱：弹速 3间")
		2:
			player.echo_scroll = true
			GameManager.echo_scroll_rooms = 3
			_add_float("宝箱：回声卷轴 3间", player.position + Vector2(-30, -42), Color(1.0, 0.886, 0.459))

func _apply_reward(card: Dictionary) -> void:
	match card.kind:
		GameManager.RewardKind.SURVIVAL:
			var gain := player.max_hp * card.value
			player.max_hp += gain
			player.hp = minf(player.max_hp, player.hp + gain)
		GameManager.RewardKind.MOVE_SPEED:
			player.speed += card.value
		GameManager.RewardKind.SHIELD:
			player.defense = minf(0.35, player.defense + card.value)
			player.shield_time = maxf(player.shield_time, 12.0)
		GameManager.RewardKind.CHEST_SPEED:
			_grant_speed_bonus(card.value, "奖励：移速 3间")
		GameManager.RewardKind.CHEST_THROW:
			_grant_throw_bonus(card.value, "奖励：弹速 3间")
		GameManager.RewardKind.CHEST_ECHO:
			player.echo_scroll = true
			GameManager.echo_scroll_rooms = 3

func _advance_room_powerups() -> void:
	# 对照 WordRogue.cs:952-990
	if GameManager.room <= 1:
		return
	if GameManager.speed_boost_rooms > 0:
		GameManager.speed_boost_rooms -= 1
		if GameManager.speed_boost_rooms == 0 and GameManager.temp_speed_bonus > 0:
			player.speed = maxf(120, player.speed - GameManager.temp_speed_bonus)
			GameManager.temp_speed_bonus = 0
			_add_float("速度道具失效", player.position + Vector2(-30, -36), Color(0.863, 0.863, 0.863))
	# （同理处理其余增益，省略以保持简洁，实现时对照原代码逐一编写）

func _on_room_cleared() -> void:
	# 对照 WordRogue.cs:2378-2411
	var accuracy := 1.0 if (GameManager.correct_hits + GameManager.wrong_hits) == 0 else float(GameManager.correct_hits) / (GameManager.correct_hits + GameManager.wrong_hits)
	if accuracy >= 0.8 and GameManager.collisions <= 1 and GameManager.room_time < 80:
		GameManager.room_difficulty_scale = minf(1.35, GameManager.room_difficulty_scale + 0.08)
		GameManager.message = "清房漂亮：下一间更有挑战"
	elif accuracy < 0.5 or GameManager.collisions >= 4 or GameManager.room_time > 100:
		GameManager.room_difficulty_scale = maxf(0.74, GameManager.room_difficulty_scale - 0.12)
		player.hp = minf(player.max_hp, player.hp + 18)
		GameManager.message = "系统降压：下间减少压迫"
	else:
		GameManager.message = "房间清空。"

	var unique_count := 0
	var seen := {}
	for w in GameManager.run_words:
		if w.word not in seen:
			seen[w.word] = true
			unique_count += 1
	if unique_count >= WordBank.bank_words.size():
		GameManager.change_state(GameManager.State.WIN)
		return

	GameManager.change_state(GameManager.State.ROOM_CLEAR)
	SaveManager.save_data.best_room = maxi(SaveManager.save_data.best_room, GameManager.room)
	SaveManager.save_game()
	# 2.2 秒后自动进入下一间
	await get_tree().create_timer(2.2).timeout
	_start_room()
```

- [ ] **Step 4: 验证**

完整游戏循环测试：
- 击杀怪物后概率掉落道具，走近自动拾取
- 宝箱可开启，获得随机增益
- 房间清空后自动进入下一间
- 第4间起弹出奖励卡选择面板（3选1）
- 增益道具3间后失效

- [ ] **Step 5: 提交**

```bash
git add word_realm/
git commit -m "feat: add drops, chests, reward cards, and room progression"
```

---

### Task 8: HUD 与结算界面

**Files:**
- Create: `word_realm/scenes/ui/hud.tscn`
- Create: `word_realm/scripts/ui/hud.gd`
- Create: `word_realm/scenes/ui/pause_menu.tscn`
- Create: `word_realm/scripts/ui/pause_menu.gd`
- Create: `word_realm/scenes/ui/game_over_screen.tscn`
- Create: `word_realm/scripts/ui/game_over_screen.gd`
- Create: `word_realm/scenes/ui/memory_book.tscn`
- Create: `word_realm/scripts/ui/memory_book.gd`
- Modify: `word_realm/scripts/game/game.gd`

**Interfaces:**
- Consumes: `GameManager.state_changed`, player 属性, `GameManager.combo`/`message`/`room`
- Produces: 完整 UI 层：HUD（血条/连击/消息/房间号）、暂停、结算、生词本

- [ ] **Step 1: 创建 HUD**

对照 `WordRogue.cs` 中 DrawHud 部分。

```
HUD (CanvasLayer, layer=5)
├── TopBar (HBoxContainer)
│   ├── HpBar (ProgressBar, 显示血量)
│   ├── RoomLabel (Label, "第 N 间：主题名")
│   └── ComboLabel (Label, "连击 x N")
├── MessageLabel (Label, 居中底部, 系统消息)
├── HeldMeaningLabel (Label, 玩家头顶, 当前持有词块)
└── Crosshair (TextureRect, 准星, 跟随鼠标)
```

```gdscript
# scripts/ui/hud.gd
extends CanvasLayer

@onready var hp_bar: ProgressBar = %HpBar
@onready var room_label: Label = %RoomLabel
@onready var combo_label: Label = %ComboLabel
@onready var message_label: Label = %MessageLabel
@onready var crosshair: TextureRect = %Crosshair

var player: Node = null

func _ready():
	crosshair.visible = not GameManager.is_mobile

func setup(p: Node) -> void:
	player = p

func _process(_delta: float) -> void:
	if player and is_instance_valid(player):
		hp_bar.value = player.hp / player.max_hp * 100
	room_label.text = "第 %d 间" % GameManager.room
	combo_label.text = "连击 ×%d" % GameManager.combo if GameManager.combo > 0 else ""
	combo_label.visible = GameManager.combo > 0
	message_label.text = GameManager.message

	if not GameManager.is_mobile:
		crosshair.position = crosshair.get_viewport().get_mouse_position() - crosshair.size / 2
```

- [ ] **Step 2: 创建暂停菜单**

```gdscript
# scripts/ui/pause_menu.gd
extends Control

signal resumed
signal quit_to_menu

func _ready():
	visible = false
	%ResumeButton.pressed.connect(func(): resumed.emit(); visible = false)
	%QuitButton.pressed.connect(func(): quit_to_menu.emit())
```

- [ ] **Step 3: 创建结算界面**

对照 `WordRogue.cs:3360-3395`（DrawEndScreen）。

```gdscript
# scripts/ui/game_over_screen.gd
extends Control

signal return_to_menu

@onready var title_label: Label = %TitleLabel
@onready var message_label: Label = %MessageLabel
@onready var word_list: VBoxContainer = %WordList

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
```

- [ ] **Step 4: 创建生词本**

对照 `WordRogue.cs` DrawMemoryBook。

```gdscript
# scripts/ui/memory_book.gd
extends Control

@onready var word_list: VBoxContainer = %BookWordList

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
```

- [ ] **Step 5: 集成 UI 到 game.gd**

```gdscript
# game.gd 中：
func _ready():
	$HUD.setup(player)
	$PauseMenu.resumed.connect(func(): GameManager.change_state(GameManager.State.PLAYING))
	$PauseMenu.quit_to_menu.connect(_quit_to_menu)
	$GameOverScreen.return_to_menu.connect(_quit_to_menu)
	$RewardPanel.reward_chosen.connect(_apply_reward)
	# ...

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE: _toggle_pause()
			KEY_TAB: $MemoryBook.toggle()

func _toggle_pause() -> void:
	if GameManager.current_state == GameManager.State.PLAYING:
		GameManager.change_state(GameManager.State.PAUSED)
		get_tree().paused = true
		$PauseMenu.visible = true
	elif GameManager.current_state == GameManager.State.PAUSED:
		GameManager.change_state(GameManager.State.PLAYING)
		get_tree().paused = false
		$PauseMenu.visible = false

func _quit_to_menu() -> void:
	get_tree().paused = false
	SaveManager.save_continue_state(player.get_player_data())
	GameManager.change_state(GameManager.State.MENU)
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
```

- [ ] **Step 6: 验证**

- HUD 实时显示血量、房间号、连击数
- Esc 暂停/恢复
- Tab 打开/关闭生词本
- 死亡和通关显示结算界面，回顾本局词汇
- PC 端显示准星跟随鼠标，移动端隐藏

- [ ] **Step 7: 提交**

```bash
git add word_realm/scenes/ui/ word_realm/scripts/ui/
git commit -m "feat: add HUD, pause menu, game over screen, and memory book"
```

---

### Task 9: 移动端触控输入

**Files:**
- Create: `word_realm/scenes/ui/touch_controls.tscn`
- Create: `word_realm/scripts/ui/touch_controls.gd`
- Modify: `word_realm/scripts/game/game.gd`（集成触控输入）
- Modify: `word_realm/scripts/game/player.gd`（移动端交互按钮联动）

**Interfaces:**
- Consumes: `GameManager.is_mobile`, player position, meaning token positions
- Produces: `TouchControls` — 信号 `move_to(pos)`, `fire_drag(dir)`, `dash_pressed`, `interact_pressed`

- [ ] **Step 1: 创建触控层场景**

```
TouchControls (CanvasLayer, layer=10, process_mode=ALWAYS)
├── InteractButton (TouchScreenButton, 左下区域, 默认隐藏)
├── DashButton (TouchScreenButton, 右下角)
├── PauseButton (TouchScreenButton, 右上角)
├── AimLine (Line2D, 拖拽瞄准方向线, 默认隐藏)
└── TouchArea (Control, full_rect, 捕获点击和拖拽)
```

- [ ] **Step 2: 编写触控脚本**

```gdscript
# scripts/ui/touch_controls.gd
extends CanvasLayer

signal move_to(pos: Vector2)
signal fire_drag(dir: Vector2)
signal dash_pressed
signal interact_pressed

@onready var interact_btn: TouchScreenButton = $InteractButton
@onready var dash_btn: TouchScreenButton = $DashButton
@onready var aim_line: Line2D = $AimLine
@onready var touch_area: Control = $TouchArea

var dragging := false
var drag_start := Vector2.ZERO
var player: Node = null

func _ready():
	visible = GameManager.is_mobile
	if not GameManager.is_mobile:
		return
	dash_btn.pressed.connect(func(): dash_pressed.emit())
	interact_btn.pressed.connect(func(): interact_pressed.emit())

func setup(p: Node) -> void:
	player = p

func _process(_delta: float) -> void:
	if not GameManager.is_mobile or player == null:
		return
	_update_interact_button()

func _update_interact_button() -> void:
	var show := false
	# 检测附近是否有可交互物（词块/宝箱）
	var meanings := get_tree().get_nodes_in_group("meaning_tokens")
	for token in meanings:
		if is_instance_valid(token) and player.position.distance_to(token.position) < player.pickup_range:
			show = true
			interact_btn.get_child(0).text = "拾取"  # 按钮文字
			break
	if not show:
		var chests := get_tree().get_nodes_in_group("chests")
		for chest in chests:
			if is_instance_valid(chest) and not chest.opened and player.position.distance_to(chest.position) < 70:
				show = true
				interact_btn.get_child(0).text = "开箱"
				break
	interact_btn.visible = show

func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.is_mobile:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			if player and player.held_meaning.length() > 0:
				dragging = true
				drag_start = event.position
				aim_line.visible = true
			else:
				var world_pos := _screen_to_world(event.position)
				move_to.emit(world_pos)
		else:
			if dragging:
				var drag_dir := (event.position - drag_start).normalized()
				if (event.position - drag_start).length() > 30:
					fire_drag.emit(drag_dir)
				dragging = false
				aim_line.visible = false

	if event is InputEventScreenDrag and dragging:
		aim_line.clear_points()
		aim_line.add_point(drag_start)
		aim_line.add_point(event.position)

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var viewport := get_viewport()
	var canvas_transform := viewport.get_canvas_transform()
	return canvas_transform.affine_inverse() * screen_pos
```

- [ ] **Step 3: 集成到 game.gd**

```gdscript
# game.gd _ready() 中增加：
if GameManager.is_mobile:
	$TouchControls.setup(player)
	$TouchControls.move_to.connect(func(pos): player.set_move_target(pos))
	$TouchControls.fire_drag.connect(func(dir): player.fire_held_meaning(dir))
	$TouchControls.dash_pressed.connect(func(): player.try_dash())
	$TouchControls.interact_pressed.connect(func(): player.try_interact(current_meanings, current_chests))
```

- [ ] **Step 4: 验证**

在 Android 设备或 Godot 编辑器的触摸模拟模式下测试：
- 点击地面，玩家自动走向目标
- 靠近词块，拾取按钮出现，点击拾取
- 持有词块时按住拖拽，出现瞄准线，松手发射
- 冲刺按钮可用
- 暂停按钮可用

- [ ] **Step 5: 提交**

```bash
git add word_realm/scenes/ui/touch_controls.tscn word_realm/scripts/ui/touch_controls.gd
git commit -m "feat: add mobile touch controls with tap-to-move and drag-to-fire"
```

---

### Task 10: 存档集成与完整游戏流程

**Files:**
- Modify: `word_realm/scripts/game/game.gd`（存档触发点、继续游戏恢复）
- Modify: `word_realm/scripts/autoload/save_manager.gd`（如需调整）
- Modify: `word_realm/scripts/ui/main_menu.gd`（继续游戏状态恢复）

**Interfaces:**
- Consumes: `SaveManager.save_continue_state()`, `SaveManager.get_continue_state()`
- Produces: 完整的存档/继续游戏循环

- [ ] **Step 1: 在关键节点触发存档**

```gdscript
# game.gd 中增加存档调用：

func _start_room() -> void:
	# ... 房间生成后 ...
	SaveManager.save_continue_state(player.get_player_data())

func _on_room_cleared() -> void:
	# ... 结算后 ...
	SaveManager.save_data.best_room = maxi(SaveManager.save_data.best_room, GameManager.room)
	SaveManager.save_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if GameManager.current_state in [GameManager.State.PLAYING, GameManager.State.ROOM_CLEAR, GameManager.State.PAUSED]:
			SaveManager.save_continue_state(player.get_player_data())
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_toggle_pause()
```

- [ ] **Step 2: 继续游戏恢复逻辑**

在 `game.gd` 中判断是否为继续游戏：

```gdscript
func _ready():
	var cs := SaveManager.get_continue_state()
	if not cs.is_empty() and SaveManager.has_continue():
		player.load_continue_state(cs)
		GameManager.piercing_ink_rooms = cs.get("piercing_ink_rooms", 0)
		GameManager.echo_scroll_rooms = cs.get("echo_scroll_rooms", 0)
		GameManager.speed_boost_rooms = cs.get("speed_boost_rooms", 0)
		GameManager.throw_boost_rooms = cs.get("throw_boost_rooms", 0)
		GameManager.dash_boost_rooms = cs.get("dash_boost_rooms", 0)
		GameManager.pickup_boost_rooms = cs.get("pickup_boost_rooms", 0)
		GameManager.temp_speed_bonus = cs.get("temp_speed_bonus", 0.0)
		GameManager.temp_throw_bonus = cs.get("temp_throw_bonus", 0.0)
		GameManager.temp_dash_bonus = cs.get("temp_dash_bonus", 0.0)
		GameManager.temp_pickup_bonus = cs.get("temp_pickup_bonus", 0.0)
		player.piercing_ink = GameManager.piercing_ink_rooms > 0
		player.echo_scroll = GameManager.echo_scroll_rooms > 0
	# 开始房间
	_start_room()
```

- [ ] **Step 3: 死亡/通关时清除继续状态**

```gdscript
func _on_player_died() -> void:
	for monster in current_monsters:
		if is_instance_valid(monster):
			monster.entry.death_count += 1
	GameManager.change_state(GameManager.State.GAME_OVER)
	SaveManager.clear_continue()
	SaveManager.save_game()
	$GameOverScreen.show_screen("探险失败", "按 Enter 回到主菜单", GameManager.run_words)
```

- [ ] **Step 4: 验证**

- 玩到第 3 间，关闭游戏
- 重新打开，主菜单显示"继续游戏：第 3 间"
- 点击继续，恢复玩家属性和增益状态
- 死亡后继续按钮消失
- Android 切后台再回来，进度不丢失

- [ ] **Step 5: 提交**

```bash
git add word_realm/
git commit -m "feat: integrate save system with continue game and mobile background save"
```

---

### Task 11: 平台导出配置

**Files:**
- Create: `word_realm/export_presets.cfg`
- Modify: `word_realm/project.godot`（补充导出相关配置）

**Interfaces:**
- Produces: 可导出 Android APK、iOS Xcode 项目、Windows EXE 的完整配置

- [ ] **Step 1: 配置 Android 导出**

在 Godot 编辑器中：
1. 项目 → 安装 Android 构建模板
2. 编辑器 → 编辑器设置 → 导出 → Android → 配置 JDK 和 SDK 路径
3. 项目 → 导出 → 添加 Android 预设：
   - 包名：`com.wordrealm.game`
   - 最低 SDK：24
   - 目标 SDK：34
   - 屏幕方向：Landscape
   - 图标：设置应用图标

- [ ] **Step 2: 配置 iOS 导出**

在 Godot 编辑器中（需 macOS）：
1. 项目 → 导出 → 添加 iOS 预设：
   - Bundle ID：`com.wordrealm.game`
   - 最低版本：15.0
   - 方向：Landscape
   - 签名：配置开发者证书

- [ ] **Step 3: 配置 Windows 导出**

在 Godot 编辑器中：
1. 项目 → 导出 → 添加 Windows 预设：
   - 应用名称：WordRealm
   - 图标：设置应用图标

- [ ] **Step 4: 验证各平台导出**

```bash
# Android（需已配置 SDK）
# 在 Godot 编辑器中：项目 → 导出 → Android → 导出项目 → word_realm.apk
# 安装到 Android 设备测试

# Windows
# 项目 → 导出 → Windows → 导出项目 → WordRealm.exe
# 运行测试

# iOS（需 macOS）
# 项目 → 导出 → iOS → 导出项目 → 在 Xcode 中打开并运行
```

- [ ] **Step 5: 提交**

```bash
git add word_realm/export_presets.cfg
git commit -m "feat: add export presets for Android, iOS, and Windows"
```
