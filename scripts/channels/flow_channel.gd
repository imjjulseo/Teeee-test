class_name FlowChannel
extends Node
## 게임 흐름용 이벤트 채널: 상태 전환, 0초 도달, 결과, 판 시작 시 옵션, 메뉴로 나가기.
## 오버레이(일시정지·결과), 입력, 패드, 보드·HUD 연출, 씬 전환이 구독한다 (연결은 main.tscn에 명시).

signal state_changed(state: GameFlow.GameState)
## 남은 시간이 0이 됐다 (부활 확인·결과 전에 한 번).
signal time_up
## RESULT 진입 시 최종 점수, (갱신 후) 최고 점수, 판에서 주운 코인.
signal result_ready(score: int, best: int, is_new_best: bool, coins: int)
## RESULT 진입 시 이 판 캐릭터의 이름과 (갱신 후) 그 캐릭터 최고 점수 (E38).
signal character_best_ready(character_name: String, best: int)
## RESULT 진입 시 판 끝 정산(레벨·경험치)과 정산 전·후 보유 코인 (결과 화면이 차오르게 보여 준다).
signal rewards_ready(rewards: RunRewards.Result, coins_before: int, coins_after: int)
## RESULT 진입 시 이번 판에 달성한 업적 [이름, 보상] (rewards_ready 다음, 없으면 빈 목록).
signal achievements_ready(lines: Array[PackedStringArray])
## REVIVE 진입 시 부활 제안: 점수, 비용(다이아), 가진 다이아, 부활하면 남는 시간.
signal revive_offered(score: int, cost: int, diamonds: int, seconds: float)
## REVIVE 동안 매 프레임: 남은 결정 시간 비율 (1 → 0).
signal revive_countdown(ratio: float)
## 게임 화면 시작 시 옵션의 조작 방법 (스와이프 / 패드).
signal control_mode_ready(mode: OptionsStore.ControlMode)
## 게임 화면 시작 시 옵션의 효과 줄이기 (흔들림·파편·떠오르는 숫자 끔).
signal reduce_motion_ready(enabled: bool)
## 일시정지에서 메뉴로 나가기로 판을 포기함 (점수 미반영).
signal quit_to_menu
## 체험 판이 결과에 도착 (보상 없음). character_name = 체험한 캐릭터.
signal trial_result_ready(character_name: String)
## 체험 판을 마치고 캐릭터 화면으로.
signal back_to_characters
## 상점에서 연 체험 판을 마치고 상점으로.
signal back_to_shop
## 규칙 튜토리얼이 끝났다 (실전 판으로 다시 연다).
signal tutorial_finished
## RESULT 진입 시 튜토리얼 흐름이 메뉴로 이끄는지 (첫 실전 판 뒤: 다시 하기 숨김).
signal result_guided(menu_only: bool)
