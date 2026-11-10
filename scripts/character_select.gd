class_name CharacterSelect
extends Control
## 캐릭터 화면 (기획서 8.1장, E38): 위 줄, 좌우로 넘기는 캐릭터 정보(CharacterCarousel), 아래 줄. 카드 목록 없이 바로 정보가 보인다.
## 장착은 CharacterCollection으로 처리한다. 해금은 상점에서 한다 (E36). 튜토리얼 및 체험은 TrialRequest에 캐릭터를 적고 trial_started
## (character_select.tscn에서 게임 씬 전환에 연결). 열릴 때 아래 줄 블럭이 올라와 정보의 블럭이 된다.

signal trial_started

@export var roster: CharacterRoster
## 튜토리얼 및 체험 (튜토리얼이 있는 캐릭터만).
@export var lessons: CharacterTutorialBook
## 처음 볼 때 안내 (처음 열면 설명한다, 8.8장).
@export var tips: FirstViewTips
@export var spotlight: SpotlightOverlay
## 블럭이 올라오는 시간.
@export var rise_time: float = 0.28
## 저장 파일. 비어 있으면 SaveData 기본 경로 (테스트·스모크는 SaveData.path_override).
@export var save_path: String = ""

var collection: CharacterCollection
var _characters: Array[CharacterData] = []
var _best: BestScoreStore
var _guides: GuideQueue

@onready var _top_bar: TopBar = %TopBar
@onready var _nav: BottomNav = %BottomNav
@onready var _carousel: CharacterCarousel = %Carousel
@onready var _flying: CharacterBlockView = %FlyingBlock


func _ready() -> void:
	collection = CharacterCollection.new(roster, ProgressStore.new(save_path), CharacterStore.new(save_path))
	_best = BestScoreStore.new(save_path)
	_characters = collection.sorted()
	_top_bar.setup(save_path)
	_nav.setup(save_path)
	_carousel.setup(_characters.size(), _render_page, _characters.find(collection.equipped_character()))
	_flying.visible = false
	var guided: bool = _queue_guide(TutorialStore.new(save_path))
	if not guided and is_inside_tree() and not OptionsStore.new(save_path).reduce_motion:
		_play_block_rise.call_deferred()


## 넘기는 판 (테스트/디버그용).
func carousel() -> CharacterCarousel:
	return _carousel


## 지금 보이는 캐릭터.
func shown_character() -> CharacterData:
	return _characters[_carousel.index]


## 그 캐릭터의 판으로 바로 넘긴다 (테스트/디버그용).
func show_character(id: StringName) -> void:
	for i: int in _characters.size():
		if _characters[i].id == id:
			_carousel.go_to(i, false)
			return


## 지금 장착한 캐릭터 id.
func selected_id() -> StringName:
	return collection.equipped_character().id


## 처음 볼 때 안내가 떠 있는지 (테스트/디버그용).
func is_guiding() -> bool:
	return _guides != null and _guides.is_open()


func _render_page(info: CharacterInfo, index: int) -> void:
	var data: CharacterData = _characters[index]
	info.show_for_equip(data, collection.status_of(data), collection.is_veiled(data), _best.best_of(data.id),
		lessons != null and lessons.find(data.id) != null)


## 처음 열면 넘기는 판 안내 (HTML spotOnce _chr). 본 기록은 튜토리얼 흐름(게임 시작이 빛남)에도 쓴다. 안내를 띄우면 true.
func _queue_guide(tutorial: TutorialStore) -> bool:
	if tips == null or spotlight == null:
		tutorial.mark_seen(TutorialStore.SEEN_CHARACTERS)
		return false
	_guides = GuideQueue.new(spotlight, tutorial)
	var area: Control = _carousel
	if not _guides.add(TutorialStore.SEEN_CHARACTERS, tips.characters_head, tips.characters_text,
			func() -> Array[Rect2]: return [area.get_global_rect()] as Array[Rect2], true):
		return false
	_carousel.input_enabled = false
	_guides.start(self)
	return true


func _on_spotlight_tapped() -> void:
	if _guides != null:
		_guides.next()
	_carousel.input_enabled = not is_guiding()
	_nav.refresh()


## 아래 줄 블럭이 올라와 정보의 블럭이 된다.
func _play_block_rise() -> void:
	await get_tree().process_frame  # 자리가 정해진 뒤
	if not is_inside_tree():
		return
	var page: CharacterInfo = _carousel.current_page()
	var from: Control = _nav.block()
	var to: Control = page.block()
	_flying.show_character(page.character, collection.is_veiled(page.character))
	_flying.global_position = from.global_position
	_flying.size = from.size
	_flying.visible = true
	to.modulate.a = 0.0
	page.modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_flying, "global_position", to.global_position, rise_time)
	tween.tween_property(_flying, "size", to.size, rise_time)
	tween.tween_property(page, "modulate:a", 1.0, rise_time)
	tween.chain().tween_callback(func() -> void:
		_flying.visible = false
		to.modulate.a = 1.0)


## 판의 장착하기 (character_select.tscn에서 연결).
func _on_equip_requested(character: CharacterData) -> void:
	if collection.equip(character):
		_carousel.refresh()
		_nav.refresh()


## 판의 튜토리얼 및 체험: 체험 판을 캐릭터 튜토리얼부터 (끝나면 이 화면으로).
func _on_lesson_requested(character: CharacterData) -> void:
	TrialRequest.character_id = character.id
	TrialRequest.with_lesson = true
	trial_started.emit()
