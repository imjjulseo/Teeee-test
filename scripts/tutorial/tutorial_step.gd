class_name TutorialStep
extends Resource
## 튜토리얼 단계 하나 (기획서 8.8장: 단계는 데이터로). 하위 클래스가 필요한 것만 덮어쓴다 (명령 패턴).
## TutorialDirector가 차례로 start → (사건들) → 단계가 director.finish_step()을 부르면 다음 단계.
## 문구의 {A} {B} {C}는 CardsStep이 고른 색 이름, {A을}은 조사까지, {next}는 첫 족보의 다음 색 이름, {done}/{count}는 진행.

## 단계가 시작될 때.
func start(_director: TutorialDirector) -> void:
	pass


## 스포트라이트 설명을 눌렀다 (TAP).
func on_tap(_director: TutorialDirector) -> void:
	pass


## 자유 매치 중 이동 한 번 (퍼즐 중이 아닐 때).
func on_move(_director: TutorialDirector) -> void:
	pass


## 본게임 매치 한 번 (퍼즐 매치 포함).
func on_match(_director: TutorialDirector, _match: TutorialDirector.MatchInfo) -> void:
	pass


## 캐릭터 튜토리얼의 사건 (TutorialMoment.ABILITY 발동 · 능력 지표 이름 · 능력의 순간 · CharacterLessonStep.RECIPE).
## amount = 지표가 더한/잰 값, 족보 완성 장 수 (순간은 0).
func on_event(_director: TutorialDirector, _event: StringName, _amount: int) -> void:
	pass


## 블럭 모으기 퍼즐 한 판이 끝났다.
func on_puzzle_finished(_director: TutorialDirector, _stars: int) -> void:
	pass


## 판 기준 시간 (설명이 판을 멈추고 있을 때는 오지 않는다).
func tick(_director: TutorialDirector, _delta: float) -> void:
	pass


## 데이터 검사 (잘못된 설정이면 오류 문구).
func validate(_book: PuzzleBook) -> PackedStringArray:
	return PackedStringArray()
