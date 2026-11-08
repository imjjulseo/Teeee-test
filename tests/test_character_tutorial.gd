extends "res://tests/framework/test_case.gd"
## 6c 캐릭터 튜토리얼 (기획서 8.8장): 데이터(31명 · 목표 이름이 그 캐릭터 능력의 지표/순간), 단계 구성,
## 처음 보는 순간 고르기, 지표 신호·순간 신호, 캐릭터 족보 채우기·바로 발동, 캐릭터별 처음 사용 기록, 튜토리얼 판 요청.

const TEST_SAVE: String = "user://test_character_tutorial_save.cfg"


func _clean() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


func before_each() -> void:
	_clean()


func after_each() -> void:
	_clean()


func _book() -> CharacterTutorialBook:
	return load("res://resources/character_tutorials.tres") as CharacterTutorialBook


func _roster() -> CharacterRoster:
	return load("res://resources/character_roster.tres") as CharacterRoster


func _session(id: StringName, seed_value: int = 3) -> GameSession:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return GameSession.new(load("res://resources/game_config.tres") as GameConfig, rng, null, _roster().find(id))


## 그 캐릭터 능력이 남기는 사건 이름 (METRIC_* · MOMENT_* 상수).
func _events_of(character: CharacterData) -> Dictionary[StringName, bool]:
	var events: Dictionary[StringName, bool] = {TutorialMoment.ABILITY: true, CharacterLessonStep.RECIPE: true}
	var constants: Dictionary = character.ability.get_script().get_script_constant_map()
	for key: String in constants:
		if key.begins_with("METRIC_") or key.begins_with("MOMENT_"):
			events[StringName(constants[key])] = true
	return events


# --- 데이터 ------------------------------------------------------------------------

func test_book_is_valid_and_covers_the_roster() -> void:
	var book: CharacterTutorialBook = _book()
	assert_eq(book.validate(load("res://resources/puzzles.tres") as PuzzleBook), PackedStringArray())
	var missing: PackedStringArray = PackedStringArray()
	for character: CharacterData in _roster().characters:
		if character.grade != CharacterData.Grade.BASIC and book.find(character.id) == null:
			missing.append(String(character.id))
	assert_eq(missing, PackedStringArray(), "every roster character has a tutorial")
	assert_eq(book.tutorials.size(), 31)
	assert_true(book.find(&"basic") == null, "the basic character has none")


func test_goals_and_moments_are_events_the_ability_reports() -> void:
	var book: CharacterTutorialBook = _book()
	var unknown: PackedStringArray = PackedStringArray()
	for tutorial: CharacterTutorial in book.tutorials:
		var character: CharacterData = _roster().find(tutorial.character_id)
		assert_true(character != null, "%s is in the roster" % tutorial.character_id)
		var events: Dictionary[StringName, bool] = _events_of(character)
		for moment: TutorialMoment in tutorial.moments:
			if not events.has(moment.event):
				unknown.append("%s moment %s" % [tutorial.character_id, moment.event])
		for lesson: CharacterLessonStep in tutorial.lessons:
			if not events.has(lesson.goal):
				unknown.append("%s goal %s" % [tutorial.character_id, lesson.goal])
			if lesson.retry_moment != &"" and not events.has(lesson.retry_moment):
				unknown.append("%s retry %s" % [tutorial.character_id, lesson.retry_moment])
		assert_eq(tutorial.on_trigger != null, character.has_recipe(), "%s: trigger moment only for keyed characters" % tutorial.character_id)
	assert_eq(unknown, PackedStringArray())


func test_steps_follow_the_html_lesson_order() -> void:
	var book: CharacterTutorialBook = _book()
	var clock: CharacterData = _roster().find(&"clock")
	var steps: Array[TutorialStep] = book.steps_for(book.find(&"clock"), clock)
	# 소개 → 캐릭터 족보 → 발동해 보기 → 활용 1개 → 준비 끝
	assert_eq(steps.size(), 5)
	assert_true(steps[0] is SayStep and (steps[0] as SayStep).head == "시계공 · 시간 정지")
	assert_eq((steps[1] as SayStep).head, "캐릭터 족보")
	assert_true(steps[2] is CharacterTriggerStep)
	assert_eq((steps[2] as CharacterTriggerStep).label, "시계공 · 발동해 보기")
	assert_true(steps[3] is CharacterLessonStep)
	assert_eq([(steps[4] as SayStep).head, (steps[4] as SayStep).button], ["시계공 준비 끝", ""])
	var wall: CharacterData = _roster().find(&"wall")
	var wall_steps: Array[TutorialStep] = book.steps_for(book.find(&"wall"), wall)
	assert_eq(wall_steps.size(), 4, "passive: intro → 2 lessons → ready")
	assert_eq((wall_steps[0] as SayStep).holes, PackedStringArray(["board", "chr"]), "passive intro lights its spot and the card")


func test_ring_path_goes_around_and_back() -> void:
	var path: Array[Vector2i] = TutorialDirector.ring_path(Vector2i(7, 7), 4, 9)
	assert_eq(path.size(), 13, "12 border cells + back to the start")
	assert_eq(path[0], Vector2i(7, 7))
	assert_eq(path[3], Vector2i(4, 7), "turns inward near the edge")
	assert_eq(path[6], Vector2i(4, 4))
	assert_eq(path[12], Vector2i(7, 7))


# --- 처음 보는 순간 ----------------------------------------------------------------

func test_moment_guide_shows_trigger_first_then_each_moment_once() -> void:
	var book: CharacterTutorialBook = _book()
	var fever: CharacterMomentGuide = CharacterMomentGuide.new(book.find(&"fever"), true)
	assert_true(fever.moment_for(FeverAbility.MOMENT_END) == null, "the trigger explanation comes first")
	assert_true(fever.moment_for(TutorialMoment.ABILITY) != null)
	assert_true(fever.moment_for(TutorialMoment.ABILITY) == null, "once")
	assert_false(fever.done)
	assert_true(fever.moment_for(FeverAbility.MOMENT_END) != null)
	assert_true(fever.done, "all moments shown")
	var clock: CharacterMomentGuide = CharacterMomentGuide.new(book.find(&"clock"), true)
	clock.moment_for(TutorialMoment.ABILITY)
	assert_true(clock.done, "no moments after the trigger")
	var sewer: CharacterMomentGuide = CharacterMomentGuide.new(book.find(&"sewer"), true)
	sewer.moment_for(TutorialMoment.ABILITY)
	assert_true(sewer.moment_for(SewerAbility.MOMENT_FAIL) != null)
	assert_true(sewer.done, "any_moment: one of success / failure is enough")
	var wall: CharacterMomentGuide = CharacterMomentGuide.new(book.find(&"wall"), false)
	assert_true(wall.moment_for(TutorialMoment.ABILITY) == null, "passive characters have no trigger moment")
	assert_true(wall.moment_for(WallAbility.METRIC_WALL_MATCHES) != null)
	assert_true(wall.done)


# --- 세션 · 지표 ------------------------------------------------------------------

func test_metrics_report_every_change() -> void:
	var metrics: RunMetrics = RunMetrics.new()
	var seen: Array = []
	metrics.changed.connect(func(key: StringName, amount: int) -> void: seen.append([key, amount]))
	metrics.add(&"a", 2)
	metrics.record_max(&"b", 3)
	metrics.record_max(&"b", 1)
	assert_eq(seen, [[&"a", 2], [&"b", 3], [&"b", 1]], "record_max reports the measured value even below the max")
	assert_eq(metrics.value(&"b"), 3)


func test_prime_and_trigger_ability() -> void:
	var session: GameSession = _session(&"clock")
	session.prime_ability_condition()
	assert_eq(session.ability_recipe.progress, session.ability_recipe.length() - 1, "one step left")
	var color: int = session.ability_recipe.next_color()
	session.advance_ability_condition(color)
	assert_eq(session.stats.ability_triggers, 1, "the last step triggers")
	session.trigger_ability()
	assert_eq(session.stats.ability_triggers, 2, "trigger without the recipe")
	assert_true((session.ability as TimeStopAbility).time_left > 4.0)


func test_fever_end_is_a_moment() -> void:
	var session: GameSession = _session(&"fever")
	var moments: Array[StringName] = []
	session.moment.connect(func(name: StringName) -> void: moments.append(name))
	session.start()
	session.trigger_ability()
	session.advance(11.0)
	assert_eq(moments, [FeverAbility.MOMENT_END] as Array[StringName])


func test_new_lesson_metrics() -> void:
	var arson: GameSession = _session(&"arson")
	var water: int = (arson.ability as ArsonAbility).water
	arson.ability.on_match(arson, 2, [] as Array[Vector2i])
	assert_eq([(arson.ability as ArsonAbility).water, arson.metrics.value(ArsonAbility.METRIC_WATER)], [water + 1, 1])
	var painter: GameSession = _session(&"painter")
	(painter.ability as PainterAbility).paint_color = 1
	painter.ability.on_match(painter, 1, [] as Array[Vector2i])
	painter.ability.on_match(painter, 0, [] as Array[Vector2i])
	assert_eq(painter.metrics.value(PainterAbility.METRIC_PAINT_MATCHES), 1)
	var racer: GameSession = _session(&"racer")
	(racer.ability as RacerAbility).streak = 3
	racer.ability.modify_match_time(racer, 1.0, null)
	assert_eq(racer.metrics.value(RacerAbility.METRIC_STREAK_MATCHES), 1)


func test_ability_hints() -> void:
	var clock: GameSession = _session(&"clock")
	var need: int = clock.ability_recipe.next_color()
	var other: int = (need + 1) % 4
	assert_true(clock.ability.prefers_hint(clock, need, Vector2i.ZERO, 1), "clock: the recipe color before the stop")
	assert_false(clock.ability.prefers_hint(clock, other, Vector2i.ZERO, 1))
	clock.trigger_ability()
	assert_true(clock.ability.prefers_hint(clock, other, Vector2i.ZERO, 1), "any match while time is stopped")
	var gardener: GameSession = _session(&"gardener")
	var seed_color: int = gardener.ability_recipe.next_color()
	assert_false(gardener.ability.prefers_hint(gardener, seed_color, Vector2i.ZERO, 6), "gardener: collect seeds with other colors first")
	assert_true(gardener.ability.prefers_hint(gardener, (seed_color + 1) % 4, Vector2i.ZERO, 6))


# --- 저장 · 요청 ------------------------------------------------------------------

func test_character_seen_is_saved() -> void:
	var store: TutorialStore = TutorialStore.new(TEST_SAVE)
	assert_false(store.has_seen_character(&"clock"))
	store.mark_character_seen(&"clock")
	assert_true(TutorialStore.new(TEST_SAVE).has_seen_character(&"clock"))
	assert_false(TutorialStore.new(TEST_SAVE).has_seen_character(&"fever"))
	store.finish_all()
	assert_true(TutorialStore.new(TEST_SAVE).has_seen_character(&"fever"), "finished saves never ask")


func test_lesson_request_is_taken_once() -> void:
	TrialRequest.character_id = &"clock"
	TrialRequest.with_lesson = true
	assert_true(TrialRequest.take_lesson())
	assert_false(TrialRequest.take_lesson())
	assert_eq(TrialRequest.take(), &"clock")
