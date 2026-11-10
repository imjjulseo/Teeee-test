class_name UiImage
extends TextureRect
## UiAssets의 이미지 자리 하나를 씬에 놓는 노드. slot에 이미지가 들어 있으면 보이고 fallback(글자·도형)을 숨긴다.
## 이미지가 비어 있으면 자기가 숨고 fallback이 보인다 → PNG를 ui_assets.tres에 끌어다 놓으면 코드 수정 없이 바뀐다.

@export var assets: UiAssets
## UiAssets의 속성 이름 (예: shop_icon).
@export var slot: StringName = &""
@export var fallback: CanvasItem


func _ready() -> void:
	refresh()


func refresh() -> void:
	var value: Variant = assets.get(slot) if assets != null and not slot.is_empty() else null
	texture = value as Texture2D
	visible = texture != null
	if fallback != null:
		fallback.visible = texture == null
