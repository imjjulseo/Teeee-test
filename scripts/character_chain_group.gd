class_name CharacterChainGroup
extends VBoxContainer
## 업적 화면 캐릭터 탭의 캐릭터 하나 (기획서 8.6장, E36): 이름·등급(등급 색)·미보유 표시와 업적 3단계 줄.
## 줄 수는 데이터로 정해지므로 row_scene을 코드에서 인스턴스화한다.

signal claim_requested(status: AchievementTracker.TierStatus)

@export var row_scene: PackedScene

var character: CharacterData
var _rows: Array[AchievementRow] = []

@onready var _name_label: Label = %ChainName
@onready var _grade_label: Label = %ChainGrade
@onready var _owned_label: Label = %ChainOwned
@onready var _list: VBoxContainer = %ChainRows


func show_chain(data: CharacterData, grade_color: Color, owned: bool, tiers: Array[AchievementTracker.TierStatus]) -> void:
	character = data
	_name_label.text = data.display_name
	_grade_label.text = CharacterData.GRADE_NAMES[data.grade]
	_grade_label.add_theme_color_override("font_color", grade_color)
	_owned_label.visible = not owned
	for status: AchievementTracker.TierStatus in tiers:
		var row: AchievementRow = row_scene.instantiate() as AchievementRow
		_list.add_child(row)
		row.show_status(status)
		row.claim_requested.connect(_on_row_claim_requested)
		_rows.append(row)


## 줄을 지금 값으로 다시 보인다.
func refresh(tiers: Array[AchievementTracker.TierStatus]) -> void:
	for i: int in mini(tiers.size(), _rows.size()):
		_rows[i].show_status(tiers[i])


## 업적 단계 줄 (테스트/디버그용).
func rows() -> Array[AchievementRow]:
	return _rows


func shows_unowned() -> bool:
	return _owned_label.visible


func _on_row_claim_requested(status: AchievementTracker.TierStatus) -> void:
	claim_requested.emit(status)
