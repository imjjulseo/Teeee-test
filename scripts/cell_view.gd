class_name CellView
extends Control
## 셀 1칸의 그래픽. 색 블록은 ColorRect + 색별 문양, 플레이어는 테두리로 구분한다.
## 디자인 이미지가 있으면(BoardTheme Art 그룹, CharacterData.portrait) 그 이미지(Art · GrowthArt · CoinArt)를 쓰고 그림은 숨긴다.
## 씨앗 칸은 자랄 색을 드러내지 않고, 중앙에서 바깥으로 차오르는 중립색 사각형으로 자람 진행도를 보여준다.

@onready var _fill: ColorRect = $Fill
@onready var _growth: ColorRect = $Growth
@onready var _glyph: GlyphView = $Glyph
@onready var _border: ReferenceRect = $Border
## 금화 표시 (기획서 4.4장). 블록 오른쪽 위의 작은 원.
@onready var _coin: GlyphView = $Coin
@onready var _art: TextureRect = $Art
@onready var _growth_art: TextureRect = $GrowthArt
@onready var _coin_art: TextureRect = $CoinArt


## character를 주면 플레이어 칸에 캐릭터 외형(채움/테두리 색)을 쓴다.
## style은 능력의 표시 방식 (색약·레트로). 칠하는 색만 바뀌고 문양은 원래 색 그대로.
func display(type: Board.CellType, color_id: int, theme_data: BoardTheme, character: CharacterData = null,
		style: DisplayStyle = null) -> void:
	size = Vector2.ONE * theme_data.cell_size
	pivot_offset = size / 2.0
	_growth.pivot_offset = size / 2.0
	_growth_art.pivot_offset = size / 2.0
	_border.visible = type == Board.CellType.PLAYER
	_border.border_width = theme_data.player_border_width
	_growth.visible = type == Board.CellType.SEED
	_growth_art.visible = false
	_show_art(null)
	match type:
		Board.CellType.PLAYER:
			_fill.color = character.player_fill if character != null else theme_data.player_fill
			_border.border_color = character.player_border if character != null else theme_data.player_border
			_glyph.set_glyph(GlyphView.Shape.NONE, theme_data.glyph_color)
			var portrait: Texture2D = character.portrait if character != null and character.portrait != null else theme_data.player_texture
			if _show_art(portrait):
				_border.visible = false
			z_index = 1
		Board.CellType.COLOR_BLOCK:
			_fill.color = theme_data.display_color(color_id, style)
			_glyph.set_glyph(theme_data.glyph_for(color_id), theme_data.glyph_color)
			if _show_art(theme_data.block_art(color_id, style)):
				_glyph.set_glyph(GlyphView.Shape.NONE, theme_data.glyph_color)  # 이미지에 문양이 그려져 있다
			z_index = 0
		Board.CellType.SEED:
			_fill.color = theme_data.seed_base_color
			_growth.color = theme_data.seed_fill_color
			_glyph.set_glyph(GlyphView.Shape.NONE, theme_data.glyph_color)
			if style != null and style.reveal_seeds:  # 예지안: 자랄 색과 문양을 흐리게 보여 준다
				var next: Color = theme_data.display_color(color_id, style)
				_fill.color = Color(next, theme_data.seed_reveal_alpha)
				_growth.color = next
				_glyph.set_glyph(theme_data.glyph_for(color_id), Color(theme_data.glyph_color, theme_data.glyph_color.a * theme_data.seed_reveal_alpha))
			elif theme_data.seed_texture != null:  # 씨앗 이미지 (자랄 색을 보여 줄 때는 그림 그대로)
				_fill.color = Color.TRANSPARENT
				_growth.visible = false
				_growth_art.texture = theme_data.seed_texture
				_growth_art.visible = true
			set_growth(0.0)
			z_index = 0
		Board.CellType.EMPTY:
			_fill.color = theme_data.empty_color
			_glyph.set_glyph(GlyphView.Shape.NONE, theme_data.glyph_color)
			z_index = 0


## 금화가 붙어 있으면 표시한다.
func show_coin(has_coin: bool, theme_data: BoardTheme) -> void:
	var art: bool = has_coin and theme_data.coin_texture != null
	_coin_art.texture = theme_data.coin_texture
	_coin_art.visible = art
	_coin.visible = has_coin and not art
	if has_coin and not art:
		_coin.set_glyph(GlyphView.Shape.CIRCLE, theme_data.coin_color)


## 금화 표시 중인지 (테스트/디버그용).
func has_coin_marker() -> bool:
	return _coin.visible or _coin_art.visible


## 씨앗 자람 진행도(0~1)만큼 중앙에서 바깥으로 채운다.
func set_growth(progress: float) -> void:
	_growth.scale = Vector2.ONE * clampf(progress, 0.0, 1.0)
	_growth_art.scale = _growth.scale


func growth_progress() -> float:
	return _growth.scale.x if _growth.visible or _growth_art.visible else 0.0


## 블록·플레이어 이미지를 쓰고 있는지 (테스트/디버그용).
func shows_art() -> bool:
	return _art.visible


## 이미지가 있으면 칸 전체에 깔고 채움색을 숨긴다. 이미지를 썼으면 true.
func _show_art(texture: Texture2D) -> bool:
	_art.texture = texture
	_art.visible = texture != null
	if texture != null:
		_fill.color = Color.TRANSPARENT
	return texture != null


## 현재 표시 중인 문양 (테스트/디버그용).
func glyph_shape() -> GlyphView.Shape:
	return _glyph.shape
