class_name FirstViewTips
extends Resource
## 처음 볼 때 안내 문구 (기획서 8.8장, HTML spotOnce): 화면·요소를 처음 볼 때 스포트라이트로 한 번씩.
<<<<<<< HEAD
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
=======
## 본 기록은 TutorialStore.seen (키는 TutorialStore.SEEN_*). 튜토리얼 담당이 이 리소스만 고치면 된다.

@export_group("Game")
## 두 족보가 같은 색을 기다리는 순간 (판 중).
@export var multi_head: String = "족보 동시 진행"
@export_multiline var multi_text: String = "두 족보를 동시에 올릴 수도 있어요"
## 첫 결과 화면의 경험치 바.
@export var experience_head: String = "경험치"
@export_multiline var experience_text: String = "점수만큼 경험치를 얻어요"

@export_group("Screens")
@export var achievements_head: String = "업적"
@export_multiline var achievements_text: String = "조건을 달성하면 코인·다이아를 받아요"
@export var hidden_head: String = "히든 업적"
@export_multiline var hidden_text: String = "조건은 비밀. 달성하면 히든 캐릭터를 얻어요"
@export var characters_head: String = "캐릭터"
@export_multiline var characters_text: String = "눌러서 능력 보기 · 다이아로 해금 · 한 판 체험 · 튜토리얼"
## 메뉴 > 퍼즐 첫 방문.
@export var puzzles_head: String = "퍼즐"
@export_multiline var puzzles_text: String = "T 모양 만들기 퍼즐이에요. 처음 깰 때마다 코인을 받아요"
>>>>>>> Choi
