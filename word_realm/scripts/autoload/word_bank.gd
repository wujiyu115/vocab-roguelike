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
			var difficulty_score: float = 40.0 - absf(w.difficulty - target_difficulty) * 9.0
			var weight: float = maxf(6.0, difficulty_score)
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
