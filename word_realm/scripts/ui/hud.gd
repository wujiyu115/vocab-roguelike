# scripts/ui/hud.gd
extends CanvasLayer

@onready var hp_bar: ProgressBar = $TopBar/HpBar
@onready var room_label: Label = $TopBar/RoomLabel
@onready var combo_label: Label = $TopBar/ComboLabel
@onready var message_label: Label = $MessageLabel
@onready var crosshair: TextureRect = $Crosshair

var player: Node = null

func _ready():
	crosshair.visible = not GameManager.is_mobile

func setup(p: Node) -> void:
	player = p

func _process(_delta: float) -> void:
	if player and is_instance_valid(player):
		hp_bar.value = player.hp / player.max_hp * 100
	room_label.text = "第 %d 间" % GameManager.room
	combo_label.text = "连击 x%d" % GameManager.combo if GameManager.combo > 0 else ""
	combo_label.visible = GameManager.combo > 0
	message_label.text = GameManager.message

	if not GameManager.is_mobile:
		crosshair.position = crosshair.get_viewport().get_mouse_position() - crosshair.size / 2
