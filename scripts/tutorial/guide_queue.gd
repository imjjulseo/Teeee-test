class_name GuideQueue
extends RefCounted
## 처음 볼 때 안내 차례 (기획서 8.8장, HTML spotOnce): 아직 안 본 안내만 줄 세우고 스포트라이트(TAP)로 하나씩 띄운다.
## 띄우는 순간 본 것으로 적는다 (TutorialStore.mark_seen). 화면이 SpotlightOverlay.tapped를 받아 next()를 부른다.
## 밝힐 곳은 Callable(→ Array[Rect2])로 띄울 때와 떠 있는 동안 매 프레임 잰다 (스크롤·레이아웃이 늦게 정해져도 따라간다).

class Guide:
	var key: String
	var head: String
	var text: String
	var holes: Callable
	var top: bool
	## 띄우기 직전에 할 일 (스크롤 등, 없으면 비어 있음).
	var before: Callable

var spotlight: SpotlightOverlay
var store: TutorialStore
var _queue: Array[Guide] = []
var _current: Guide
var _owner: Node


func _init(p_spotlight: SpotlightOverlay, p_store: TutorialStore) -> void:
	spotlight = p_spotlight
	store = p_store


## 아직 안 본 안내면 줄에 넣는다. 넣었으면 true.
func add(key: String, head: String, text: String, holes: Callable, top: bool = false, before: Callable = Callable()) -> bool:
	if store.has_seen(key) or _has(key):
		return false
	var guide: Guide = Guide.new()
	guide.key = key
	guide.head = head
	guide.text = text
	guide.holes = holes
	guide.top = top
	guide.before = before
	_queue.append(guide)
	return true


## 레이아웃이 정해진 뒤(두 프레임) 첫 안내를 띄운다.
func start(owner: Node) -> void:
	if _queue.is_empty() or spotlight == null:
		return
	_owner = owner
	if not owner.get_tree().process_frame.is_connected(_refresh):
		owner.get_tree().process_frame.connect(_refresh)
	await owner.get_tree().process_frame
	await owner.get_tree().process_frame
	if is_instance_valid(owner) and _current == null:
		next()


## 지금 안내를 닫고 다음 안내를 띄운다 (없으면 닫기만).
func next() -> void:
	_current = null
	if _queue.is_empty():
		spotlight.close()
		_stop_refresh()
		return
	_current = _queue.pop_front()
	store.mark_seen(_current.key)
	var guide: Guide = _current
	if guide.before.is_valid():  # 스크롤 등이 반영된 뒤 자리를 잰다
		guide.before.call()
		if _owner != null and is_instance_valid(_owner):
			spotlight.close()
			await _owner.get_tree().process_frame
		if _current != guide:
			return
	var rects: Array[Rect2] = _current.holes.call() if _current.holes.is_valid() else ([] as Array[Rect2])
	spotlight.open(SpotlightOverlay.Mode.TAP, _current.head, _current.text, rects, "", false, _current.top)


## 지금 떠 있는 안내 키 (없으면 빈 값).
func current_key() -> String:
	return _current.key if _current != null else ""


func is_open() -> bool:
	return _current != null


func _refresh() -> void:
	if _current != null and spotlight.is_open() and _current.holes.is_valid():
		spotlight.update_holes(_current.holes.call())


func _stop_refresh() -> void:
	if _owner != null and is_instance_valid(_owner) and _owner.is_inside_tree() and _owner.get_tree().process_frame.is_connected(_refresh):
		_owner.get_tree().process_frame.disconnect(_refresh)


func _has(key: String) -> bool:
	for guide: Guide in _queue:
		if guide.key == key:
			return true
	return false
