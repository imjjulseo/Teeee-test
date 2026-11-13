class_name FirstViewTips
extends Resource
## 처음 볼 때 안내 문구 (기획서 8.8장, HTML spotOnce): 화면·요소를 처음 볼 때 스포트라이트로 한 번씩.
## 본 기록은 TutorialStore.seen (키는 TutorialStore.SEEN_*). 문구는 resources/first_view_tips.tres에만 둔다 (스크립트 기본값은 비워 둔다).

@export_group("Game")
## 두 족보가 같은 색을 기다리는 순간 (판 중).
@export var multi_head: String = ""
@export_multiline var multi_text: String = ""
## 첫 결과 화면의 경험치 바.
@export var experience_head: String = ""
@export_multiline var experience_text: String = ""

@export_group("Screens")
@export var achievements_head: String = ""
@export_multiline var achievements_text: String = ""
@export var hidden_head: String = ""
@export_multiline var hidden_text: String = ""
@export var characters_head: String = ""
@export_multiline var characters_text: String = ""
## 메뉴 > 퍼즐 첫 방문.
@export var puzzles_head: String = ""
@export_multiline var puzzles_text: String = ""
