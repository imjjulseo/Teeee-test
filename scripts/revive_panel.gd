class_name RevivePanel
extends CanvasLayer
## 부활 확인 (REVIVE 상태, 기획서 5장 · 8.4장, E10): "시간 종료", 이번 판 점수, 남은 결정 시간 게이지(E36), 다이아로 부활(+N초) / 끝내기.
## 시간 계산과 시간 초과는 GameFlow가 하고, 게이지는 revive_countdown을 따라 그리기만 한다. 버튼은 revive_accepted / revive_declined로만 알린다 (다이아 차감·시간은 GameController와 GameFlow가 한다).

signal revive_accepted
signal revive_declined

@onready var _score_label: Label = %ReviveScoreLabel
@onready var _revive_button: Button = %ReviveButton
@onready var _wallet_label: Label = %ReviveWalletLabel
@onready var _gauge_fill: ColorRect = %ReviveGaugeFill


func _ready() -> void:
	visible = false


## 부활 제안 내용: 점수, 비용(다이아), 가진 다이아, 부활하면 남는 시간.
func _on_revive_offered(score: int, cost: int, diamonds: int, seconds: float) -> void:
	_score_label.text = str(score)
	_revive_button.text = "◆ %d  부활 +%s초" % [cost, Ability.format_number(seconds)]
	_wallet_label.text = "보유 ◆ %d" % diamonds
	_on_revive_countdown(1.0)


func _on_revive_countdown(ratio: float) -> void:
	_gauge_fill.anchor_right = ratio


## 게이지 비율 (테스트/디버그용).
func gauge_ratio() -> float:
	return _gauge_fill.anchor_right


func _on_state_changed(state: GameFlow.GameState) -> void:
	var was_visible: bool = visible
	visible = state == GameFlow.GameState.REVIVE
	if visible and not was_visible:
		OverlayIn.play(get_node_or_null("Center") as Control)  # 카드가 커지며 나타남 (HTML ovgIn)


func _on_revive_button_pressed() -> void:
	revive_accepted.emit()


func _on_end_button_pressed() -> void:
	revive_declined.emit()
