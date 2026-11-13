class_name TrialRequest
extends RefCounted
## 체험 한 판 요청 (기획서 8.5장): 캐릭터 화면이 체험할 캐릭터를 적어 두고 게임 씬으로 넘어가면, GameController가 읽고 지운다.
## 씬끼리 서로 참조하지 않으려고 (순환 로드) 정적 값 하나로 넘긴다. 테스트 러너가 되돌리지 않은 값을 실패로 센다.
<<<<<<< HEAD
## 체험 판은 늘 그 캐릭터의 튜토리얼이다 (E38: 튜토리얼 / 체험).

## 체험할 캐릭터 id (없으면 빈 값).
static var character_id: StringName = &""
=======
## with_lesson이면 체험 판을 캐릭터 튜토리얼부터 시작한다 (캐릭터 상세의 "튜토리얼 다시 하기", 8.8장).

## 체험할 캐릭터 id (없으면 빈 값).
static var character_id: StringName = &""
## 캐릭터 튜토리얼부터 (take가 함께 지운다).
static var with_lesson: bool = false
>>>>>>> Choi
## 체험을 상점에서 열었다: 끝나면 상점(상점 탭)으로 돌아간다. 상점 화면이 take_back_to_shop으로 지운다 (E37).
static var back_to_shop: bool = false


static func take_back_to_shop() -> bool:
	var back: bool = back_to_shop
	back_to_shop = false
	return back


## 요청이 있으면 꺼내고 지운다.
static func take() -> StringName:
	var id: StringName = character_id
	character_id = &""
	return id

<<<<<<< HEAD
=======

## 튜토리얼 요청을 꺼내고 지운다 (take 전에 읽는다).
static func take_lesson() -> bool:
	var lesson: bool = with_lesson
	with_lesson = false
	return lesson
>>>>>>> Choi
