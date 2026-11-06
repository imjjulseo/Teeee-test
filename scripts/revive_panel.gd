class_name RevivePanel
extends CanvasLayer
## 부활 확인 (REVIVE 상태, 기획서 5장 · 8.4장, E10): "시간 종료", 이번 판 점수, 다이아로 부활(+N초) / 끝내기.
## 버튼은 revive_accepted / revive_declined로만 알린다 (다이아 차감·시간은 GameController와 GameFlow가 한다).

signal revive_accepted
signal revive_declined

@onready var _score_label: Label = %ReviveScoreLabel
@onready var _revive_button: Button = %ReviveButton
@onready var _wallet_label: Label = %ReviveWalletLabel


func _ready() -> void:
	visible = false


## 부활 제안 내용: 점수, 비용(다이아), 가진 다이아, 부활하면 남는 시간.
func _on_revive_offered(score: int, cost: int, diamonds: int, seconds: float) -> void:
	_score_label.text = str(score)
	_revive_button.text = "◆ %d  부활 +%s초" % [cost, Ability.format_number(seconds)]
	_wallet_label.text = "보유 ◆ %d" % diamonds


func _on_state_changed(state: GameFlow.GameState) -> void:
	visible = state == GameFlow.GameState.REVIVE


func _on_revive_button_pressed() -> void:
	revive_accepted.emit()


func _on_end_button_pressed() -> void:
	revive_declined.emit()
