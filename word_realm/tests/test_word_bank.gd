# tests/test_word_bank.gd
extends "res://tests/base_test.gd"

func _init():
	_suite_name = "WordBank"

func test_all_words_not_empty():
	assert_true(WordBank.all_words.size() > 0, "all_words is not empty")

func test_default_words_have_required_fields():
	if WordBank.all_words.is_empty():
		assert_true(false, "has 'word' field (all_words empty)")
		return
	var word: Dictionary = WordBank.all_words[0]
	assert_has_key(word, "word", "has 'word' field")
	assert_has_key(word, "meaning", "has 'meaning' field")
	assert_has_key(word, "difficulty", "has 'difficulty' field")
	assert_has_key(word, "frequency_rank", "has 'frequency_rank' field")
	assert_has_key(word, "tags", "has 'tags' field")
	assert_has_key(word, "seen_count", "has 'seen_count' field")
	assert_has_key(word, "correct_count", "has 'correct_count' field")
	assert_has_key(word, "wrong_count", "has 'wrong_count' field")
	assert_has_key(word, "death_count", "has 'death_count' field")
	assert_has_key(word, "mastery", "has 'mastery' field")
	assert_has_key(word, "last_seen_room", "has 'last_seen_room' field")

func test_default_words_word_not_empty():
	for w in WordBank.all_words:
		var word_str: String = w.word
		if word_str.is_empty():
			assert_true(false, "word string should not be empty")
			return
	assert_true(true, "all words have non-empty word strings")

func test_default_words_meaning_not_empty():
	for w in WordBank.all_words:
		var meaning_str: String = w.meaning
		if meaning_str.is_empty():
			assert_true(false, "meaning should not be empty")
			return
	assert_true(true, "all words have non-empty meanings")

func test_set_difficulty_filters():
	WordBank.set_difficulty(2)
	for w in WordBank.bank_words:
		var diff: int = w.difficulty
		if diff > 2:
			assert_true(false, "difficulty filter allows difficulty > 2")
			WordBank.set_difficulty(99)
			return
	assert_true(true, "set_difficulty(2) filters to difficulty <= 2")
	WordBank.set_difficulty(99)

func test_set_difficulty_not_empty():
	WordBank.set_difficulty(1)
	assert_true(WordBank.bank_words.size() > 0, "bank_words not empty after set_difficulty(1)")
	WordBank.set_difficulty(99)

func test_pick_room_words_count():
	WordBank.set_difficulty(99)
	GameManager.room = 1
	var picked: Array[Dictionary] = WordBank.pick_room_words(3)
	assert_eq(picked.size(), 3, "pick_room_words(3) returns 3 words")
	GameManager.room = 0

func test_pick_room_words_no_duplicates():
	WordBank.set_difficulty(99)
	GameManager.room = 1
	var picked: Array[Dictionary] = WordBank.pick_room_words(5)
	var seen_words: Dictionary = {}
	var has_dup := false
	for w in picked:
		var word_str: String = w.word
		if word_str in seen_words:
			has_dup = true
			break
		seen_words[word_str] = true
	assert_false(has_dup, "pick_room_words returns no duplicates")
	GameManager.room = 0

func test_pick_room_words_returns_valid_entries():
	WordBank.set_difficulty(99)
	GameManager.room = 1
	var picked: Array[Dictionary] = WordBank.pick_room_words(2)
	for w in picked:
		assert_has_key(w, "word", "picked word has 'word' field")
		assert_has_key(w, "meaning", "picked word has 'meaning' field")
	GameManager.room = 0

func test_get_distractors_excludes_meanings():
	WordBank.set_difficulty(99)
	var exclude: Array[String] = ["increase_meaning_placeholder"]
	if WordBank.all_words.size() > 0:
		var first_meaning: String = WordBank.all_words[0].meaning
		exclude = [first_meaning]
	var distractors: Array[Dictionary] = WordBank.get_distractors(3, exclude.duplicate())
	for d in distractors:
		var d_meaning: String = d.meaning
		if exclude.size() == 1 and d_meaning == exclude[0]:
			assert_true(false, "distractor should not match excluded meaning")
			return
	assert_true(true, "distractors exclude specified meanings")

func test_share_tag_true():
	var a := {"tags": ["verb", "academic"]}
	var b := {"tags": ["academic", "noun"]}
	var result: bool = WordBank._share_tag(a, b)
	assert_true(result, "_share_tag returns true for shared tag 'academic'")

func test_share_tag_false():
	var a := {"tags": ["verb"]}
	var b := {"tags": ["noun"]}
	var result: bool = WordBank._share_tag(a, b)
	assert_false(result, "_share_tag returns false for no shared tags")

func test_share_tag_empty():
	var a := {"tags": []}
	var b := {"tags": ["noun"]}
	var result: bool = WordBank._share_tag(a, b)
	assert_false(result, "_share_tag returns false when one has empty tags")

func test_merge_saved_stats():
	if WordBank.all_words.is_empty():
		assert_true(false, "merge_saved_stats (all_words empty)")
		return
	var first_word: Dictionary = WordBank.all_words[0]
	var original_seen: int = first_word.seen_count
	var word_str: String = first_word.word
	var saved := [{"word": word_str, "seen_count": 42, "correct_count": 10, "wrong_count": 2, "death_count": 1, "mastery": 5, "last_seen_room": 3}]
	WordBank.merge_saved_stats(saved)
	assert_eq(first_word.seen_count, 42, "merge_saved_stats updates seen_count")
	assert_eq(first_word.correct_count, 10, "merge_saved_stats updates correct_count")
	first_word.seen_count = original_seen
	first_word.correct_count = 0
	first_word.wrong_count = 0
	first_word.death_count = 0
	first_word.mastery = 0
	first_word.last_seen_room = 0
