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
