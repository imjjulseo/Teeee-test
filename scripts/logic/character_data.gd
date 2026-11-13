class_name CharacterData
extends Resource
## 캐릭터 1명의 데이터 (기획서 5.2장): 표시 정보, 캐릭터 족보(능력 발동 색 순서), 능력, 외형.
## 능력의 동작과 수치는 ability(Ability 하위 클래스 리소스)에 있다.
## 색 ID: 0 노랑, 1 빨강, 2 파랑, 3 초록 (E16).

## 등급 (기획서 5.2장 표). 뽑기 확률·상점 가격·선택권이 등급별이다. 히든은 히든 업적으로만 얻는다.
enum Grade { BASIC, RARE, HERO, LEGEND, MYTH, HIDDEN }

## 등급 이름 (Grade 순서).
const GRADE_NAMES: PackedStringArray = ["기본", "희귀", "영웅", "전설", "신화", "히든"]
## 등급 문자 (Grade 순서, HUD 캐릭터 줄). 희귀 C · 영웅 B · 전설 A · 신화 S (E26의 선택권 표기와 같은 줄), 히든 H.
const GRADE_LETTERS: PackedStringArray = ["", "C", "B", "A", "S", "H"]

## HTML 프로토타입과 같은 id (저장·업적·도감의 키).
@export var id: StringName = &""
@export var display_name: String = ""
@export var grade: Grade = Grade.BASIC
## 능력. null이면 능력 없음.
@export var ability: Ability
## 캐릭터 카드·발동 배너의 짧은 능력 이름 (예: "촉진"). 배너는 "촉진!".
@export var ability_name: String = ""
<<<<<<< HEAD
## 능력 규칙 요약 (기획서 5.2장 표의 "능력" 칸과 같다). 화면에는 summary를 쓴다.
@export_multiline var ability_description: String = ""
## 화면에 보이는 한 줄 설명 (발동 배너, 뽑기 결과, 캐릭터 튜토리얼 소개). 말투는 docs/copy_guide.md.
@export_multiline var summary: String = ""
=======
## 캐릭터 선택 화면과 발동 배너의 능력 설명 (기획서 5.2장 표의 "능력" 칸).
@export_multiline var ability_description: String = ""
>>>>>>> Choi
## 캐릭터 상세 시트 (8.1장)의 효과 자세한 설명. 비어 있으면 능력 설명을 쓴다.
@export_multiline var detail_effect: String = ""
## 캐릭터 족보: 이 색 순서대로 블록을 깨면 능력 발동. 비어 있으면 발동형이 아니다.
@export var condition_colors: PackedInt32Array = PackedInt32Array()

@export_group("Appearance")
## 캐릭터 이미지 (한 장). 판 위 플레이어·캐릭터 카드·상세 시트·뽑기 결과·상점 줄·뽑기 목록에 쓴다. 비어 있으면 아래 색으로 그린다.
@export var portrait: Texture2D
## 캐릭터 색: 발동 섬광·배너, 능력 배경 효과, 캐릭터 카드 테두리.
@export var accent_color: Color = Color("e6f0f2")
@export var player_fill: Color = Color("1d1f26")
@export var player_border: Color = Color("ffffff")


<<<<<<< HEAD
## 화면에 보일 한 줄 설명. summary가 비어 있으면 규칙 요약을 쓴다.
func player_summary() -> String:
	return summary if not summary.is_empty() else ability_description


=======
>>>>>>> Choi
## 등급 문자 (기본은 빈 문자열).
func grade_letter() -> String:
	return GRADE_LETTERS[grade] if grade >= 0 and grade < GRADE_LETTERS.size() else ""


## 능력이 있다 (발동형 또는 상시형).
func has_ability() -> bool:
	return ability != null


## 발동형: 캐릭터 족보를 완성하면 능력이 발동한다. 상시형은 족보가 없다.
func has_recipe() -> bool:
	return ability != null and not condition_colors.is_empty()
