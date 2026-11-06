@tool
class_name TokenRect
extends ColorRect
## 디자인 토큰 색으로 칠하는 단색 사각형 (배경·진행 막대): 색을 직접 적지 않고 token 이름만 둔다 (기획서 7.3장).
## 색은 테마의 DesignTokens.THEME_TYPE 색에서 읽고, 테마가 바뀌면 다시 칠한다 (에디터에서도 보인다).

@export var token: StringName = &"":
	set(value):
		token = value
		_apply()


func _ready() -> void:
	_apply()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_apply()


func _apply() -> void:
	if token != &"" and has_theme_color(token, DesignTokens.THEME_TYPE):
		color = get_theme_color(token, DesignTokens.THEME_TYPE)
