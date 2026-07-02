# scripts/autoload/audio_manager.gd
extends Node

# 基础音效系统：用 AudioStreamPlayer 池实现"多通道 + 最小间隔节流"，
# 避免同一音效连发时互相打断或产生刺耳叠加。
# 对应上游 C# 提交里的 winmm 多别名 + 后台队列方案，Godot 用原生播放器即可。

# 每种音效的配置：资源路径、通道数（同时可播放的实例数）、最小触发间隔（毫秒）
const SOUND_CONFIG := {
	"ui_click": {"path": "res://assets/sounds/ui_click.mp3", "channels": 2, "min_interval_ms": 35},
	"hit_correct": {"path": "res://assets/sounds/hit_correct.mp3", "channels": 4, "min_interval_ms": 45},
}

# key -> { "players": Array[AudioStreamPlayer], "cursor": int, "min_interval_ms": int, "last_tick": int }
var _sounds := {}

func _ready() -> void:
	for key in SOUND_CONFIG:
		var cfg: Dictionary = SOUND_CONFIG[key]
		var stream := load(cfg.path) as AudioStream
		if stream == null:
			# 缺资源时静默降级，不注册该音效
			continue
		var players: Array[AudioStreamPlayer] = []
		for i in range(cfg.channels):
			var p := AudioStreamPlayer.new()
			p.stream = stream
			p.bus = "Master"
			add_child(p)
			players.append(p)
		_sounds[key] = {
			"players": players,
			"cursor": 0,
			"min_interval_ms": cfg.min_interval_ms,
			"last_tick": -cfg.min_interval_ms,
		}

func play(key: String) -> void:
	var entry: Dictionary = _sounds.get(key, {})
	if entry.is_empty():
		return

	var now := Time.get_ticks_msec()
	if now - int(entry.last_tick) < int(entry.min_interval_ms):
		return
	entry.last_tick = now

	# 轮转选择通道，避免打断上一次尚未播完的同类音效
	var players: Array = entry.players
	var player: AudioStreamPlayer = players[entry.cursor]
	entry.cursor = (int(entry.cursor) + 1) % players.size()
	player.play()
