# scripts/ui/hud.gd
extends CanvasLayer

@onready var top_bar: PanelContainer = $TopBar
@onready var hp_bar: ProgressBar = $TopBar/HBox/HpBar
@onready var room_label: Label = $TopBar/HBox/RoomLabel
@onready var combo_label: Label = $TopBar/HBox/ComboLabel
@onready var held_label: Label = $TopBar/HBox/HeldLabel
@onready var dash_label: Label = $TopBar/HBox/DashLabel
@onready var message_label: Label = $MessageLabel
@onready var crosshair: TextureRect = $Crosshair

var player: Node = null

func _ready() -> void:
	crosshair.visible = not GameManager.is_mobile
	_style_top_bar()
	_style_hp_bar()
	_style_message()

func setup(p: Node) -> void:
	player = p

func _style_top_bar() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.12, 0.88)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	top_bar.add_theme_stylebox_override("panel", style)

func _style_hp_bar() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.2, 0.15, 0.15, 0.8)
	bg.set_corner_radius_all(4)
	hp_bar.add_theme_stylebox_override("background", bg)

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.3, 0.75, 0.3)
	fill.set_corner_radius_all(4)
	hp_bar.add_theme_stylebox_override("fill", fill)

func _style_message() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.12, 0.7)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	message_label.add_theme_stylebox_override("normal", style)

func _process(_delta: float) -> void:
	if player and is_instance_valid(player):
		hp_bar.value = player.hp / player.max_hp * 100
		# HP bar color
		var ratio: float = player.hp / player.max_hp
		var fill := hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill:
			if ratio > 0.5:
				fill.bg_color = Color(0.3, 0.75, 0.3)
			elif ratio > 0.25:
				fill.bg_color = Color(0.85, 0.7, 0.2)
			else:
				fill.bg_color = Color(0.85, 0.25, 0.2)

		# Held meaning
		if player.held_meaning.is_empty():
			held_label.text = "持有：无"
			held_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		else:
			held_label.text = "持有：" + player.held_meaning
			held_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))

		# Dash
		if player.dash_timer > 0:
			dash_label.text = "闪避 %.1fs" % player.dash_timer
			dash_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		else:
			dash_label.text = "闪避 就绪"
			dash_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))

	# Room info
	var theme_data: Dictionary = GameManager.get_current_theme()
	var theme_name: String = theme_data.get("name", "")
	room_label.text = "房间 %d：%s  %s" % [GameManager.room, theme_name, GameManager.selected_mode_name]

	# Combo & accuracy
	var total_shots: int = GameManager.correct_hits + GameManager.wrong_hits
	var accuracy: int = 0
	if total_shots > 0:
		accuracy = roundi(float(GameManager.correct_hits) / total_shots * 100)
	if GameManager.combo > 0:
		combo_label.text = "连击 %d  命中率 %d%%" % [GameManager.combo, accuracy]
		combo_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	else:
		combo_label.text = "连击 0  命中率 %d%%" % accuracy
		combo_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))

	message_label.text = GameManager.message

	if not GameManager.is_mobile:
		crosshair.position = crosshair.get_viewport().get_mouse_position() - crosshair.size / 2
