class_name WalletView
extends HBoxContainer
## 지갑 표시 (메뉴·상점·캐릭터·업적 화면 위): 코인과 다이아. UiAssets에 아이콘 이미지가 있으면 "●" "◆" 대신 아이콘.
## 주인이 show_amounts를 _ready보다 먼저 불러도 되게 자식은 그때그때 찾는다.

@export var assets: UiAssets
@export var font_size: int = 48

## 지금 보이는 글자 (아이콘이 없으면 "● 340  ◆ 25", 있으면 "340  25").
var text: String:
	get:
		return "%s  %s" % [(%CoinAmount as Label).text, (%DiamondAmount as Label).text]

var _styled: bool = false


func _ready() -> void:
	_apply_style()


func show_amounts(coins: int, diamonds: int) -> void:
	_apply_style()
	(%CoinAmount as Label).text = ("%d" if (%CoinIcon as Control).visible else "● %d") % coins
	(%DiamondAmount as Label).text = ("%d" if (%DiamondIcon as Control).visible else "◆ %d") % diamonds


## 글자 크기와 아이콘 이미지를 한 번 맞춘다.
func _apply_style() -> void:
	if _styled:
		return
	_styled = true
	for label: Label in [%CoinAmount as Label, %DiamondAmount as Label]:
		label.add_theme_font_size_override("font_size", font_size)
	_set_icon(%CoinIcon as TextureRect, assets.coin_icon if assets != null else null)
	_set_icon(%DiamondIcon as TextureRect, assets.diamond_icon if assets != null else null)


func _set_icon(icon: TextureRect, texture: Texture2D) -> void:
	icon.texture = texture
	icon.visible = texture != null
	icon.custom_minimum_size = Vector2.ONE * font_size
