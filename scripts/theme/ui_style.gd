class_name UiStyle
extends Resource
## 테마의 모양 변형 하나 (판넬·버튼·슬라이더): 모양(모서리·여백·테두리 두께)은 template, 색은 토큰 이름.
## UiThemeBuilder가 template을 복사해 토큰 색을 칠하고 base_type의 변형 name의 slots에 넣는다.
## 같은 name으로 여러 개를 두면 슬롯마다 다른 모양 (슬라이더 바탕 · 채움).
## texture(한 장 이미지)가 있으면 단색 모양 대신 9분할 이미지 판넬(StyleBoxTexture)이 된다 — 늘어나지 않는 가장자리 폭은
## texture_margins(왼쪽·위·오른쪽·아래 px), 안쪽 여백은 template의 content margin을 그대로 쓴다. 이때 토큰 색은 쓰지 않는다.

@export var name: StringName = &""
## 변형의 바탕 타입 (PanelContainer · Panel · Button · HSlider).
@export var base_type: StringName = &"PanelContainer"
## 스타일 슬롯 (panel / normal · hover · pressed / slider …).
@export var slots: PackedStringArray = PackedStringArray(["panel"])
@export var template: StyleBoxFlat
@export var bg_token: StringName = &""
## 비어 있으면 테두리 색을 바꾸지 않는다.
@export var border_token: StringName = &""
## 디자인 이미지 (비어 있으면 template + 토큰 색).
@export var texture: Texture2D
@export var texture_margins: Vector4 = Vector4.ZERO
