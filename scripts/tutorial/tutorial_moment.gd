class_name TutorialMoment
extends Resource
## 캐릭터 튜토리얼의 "처음 보는 순간" 설명 한 장 (기획서 8.8장, HTML CT.on / CT.ev): 그 사건이 처음 일어나면
## 볼 곳을 밝히고 한 줄 설명을 띄운다 (누르면 계속, 그동안 판은 멈춘다).
## 사건 이름: ABILITY = 능력 발동, 능력 지표 이름(RunMetrics, 예: wall_matches), 능력의 순간 이름(GameSession.notify_moment, 예: fever_end).

const ABILITY: StringName = &"ability"

@export var event: StringName = ABILITY
## 밝힐 곳 (TutorialDirector.holes_for: board · player · marks · cards · chr · score · time …).
@export var holes: PackedStringArray = PackedStringArray()
@export_multiline var text: String = ""
