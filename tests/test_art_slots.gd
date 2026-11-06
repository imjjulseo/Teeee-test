extends "res://tests/framework/test_case.gd"
## 디자인 이미지 자리 (한 장 이미지): 비어 있으면 지금 그림, 있으면 이미지. 블록 이미지는 문양 포함이라 능력이 색을 바꾸는 동안은 그림으로.

const DUMMY: String = "res://icon.svg"


func _texture() -> Texture2D:
	return load(DUMMY) as Texture2D


func _theme_with_art() -> BoardTheme:
	var theme: BoardTheme = (load("res://resources/board_theme.tres") as BoardTheme).duplicate() as BoardTheme
	var art: Texture2D = _texture()
	theme.block_textures = [art, art, art, art] as Array[Texture2D]
	theme.seed_texture = art
	theme.coin_texture = art
	theme.player_texture = art
	theme.mark_textures = {BoardMark.Kind.FLAG: art} as Dictionary[int, Texture2D]
	theme.chest_closed_texture = art
	return theme


func _cell() -> CellView:
	var cell: CellView = (load("res://scenes/cell_view.tscn") as PackedScene).instantiate() as CellView
	cell.notification(Node.NOTIFICATION_READY)
	return cell


func test_shipped_slots_are_empty() -> void:
	var theme: BoardTheme = load("res://resources/board_theme.tres") as BoardTheme
	assert_eq([theme.block_textures.size(), theme.seed_texture, theme.coin_texture, theme.player_texture, theme.mark_textures.size()],
		[0, null, null, null, 0], "no art yet → the drawn look")
	var assets: UiAssets = load("res://resources/ui_assets.tres") as UiAssets
	assert_eq([assets.logo, assets.coin_icon, assets.diamond_icon], [null, null, null])


func test_block_art_falls_back_while_colors_change() -> void:
	var theme: BoardTheme = _theme_with_art()
	assert_true(theme.block_art(2) != null)
	assert_true(theme.block_art(7) == null, "unknown color")
	var reveal: DisplayStyle = DisplayStyle.new()
	reveal.reveal_seeds = true
	assert_true(theme.block_art(2, reveal) != null, "seer keeps block art")
	var merged: DisplayStyle = DisplayStyle.new()
	merged.color_alias = {1: 0} as Dictionary[int, int]
	assert_true(theme.block_art(2, merged) == null, "colorblind / vampire: every block drawn (art has the color baked in)")
	var mono: DisplayStyle = DisplayStyle.new()
	mono.monochrome = true
	assert_true(theme.block_art(0, mono) == null, "retro: drawn in gray")
	assert_true(theme.mark_art(BoardMark.Kind.FLAG) != null and theme.mark_art(BoardMark.Kind.ZONE) == null)


func test_cell_uses_art_only_when_given() -> void:
	var cell: CellView = _cell()
	var plain: BoardTheme = load("res://resources/board_theme.tres") as BoardTheme
	cell.display(Board.CellType.COLOR_BLOCK, 2, plain)
	assert_false(cell.shows_art(), "no art → color + glyph")
	var theme: BoardTheme = _theme_with_art()
	cell.display(Board.CellType.COLOR_BLOCK, 2, theme)
	assert_true(cell.shows_art(), "block image")
	cell.display(Board.CellType.PLAYER, Board.NO_COLOR, theme)
	assert_true(cell.shows_art(), "player image")
	var mono: DisplayStyle = DisplayStyle.new()
	mono.monochrome = true
	cell.display(Board.CellType.COLOR_BLOCK, 2, theme, null, mono)
	assert_false(cell.shows_art(), "retro → drawn")
	cell.show_coin(true, theme)
	assert_true(cell.has_coin_marker(), "coin image counts as the coin marker")
	cell.free()


func test_character_portrait_slot() -> void:
	var character: CharacterData = (load("res://resources/character_roster.tres") as CharacterRoster).find(&"clock").duplicate() as CharacterData
	var portrait: PortraitRect = PortraitRect.new()
	assert_false(portrait.show_character(character), "no portrait yet")
	character.portrait = _texture()
	assert_true(portrait.show_character(character))
	assert_false(portrait.show_character(character, true), "hidden character stays veiled")
	portrait.free()
	var cell: CellView = _cell()
	cell.display(Board.CellType.PLAYER, Board.NO_COLOR, load("res://resources/board_theme.tres") as BoardTheme, character)
	assert_true(cell.shows_art(), "the character image on the board")
	cell.free()


func test_image_panel_style() -> void:
	var style: UiStyle = (load(UiThemeBuilder.SPEC_PATH) as UiThemeSpec).styles[0].duplicate() as UiStyle
	style.texture = _texture()
	style.texture_margins = Vector4(12, 10, 12, 14)
	var box: StyleBoxTexture = UiThemeBuilder.style_box(style, load(UiThemeBuilder.TOKENS_PATH) as DesignTokens) as StyleBoxTexture
	assert_true(box != null and box.texture == style.texture, "image panel")
	assert_eq([box.texture_margin_left, box.texture_margin_top, box.texture_margin_bottom], [12.0, 10.0, 14.0])
	assert_eq(box.get_content_margin(SIDE_LEFT), style.template.get_content_margin(SIDE_LEFT), "content margins from the template")


func test_wallet_icons() -> void:
	var wallet: WalletView = (load("res://scenes/wallet_view.tscn") as PackedScene).instantiate() as WalletView
	wallet.show_amounts(340, 25)
	assert_eq(wallet.text, "● 340  ◆ 25", "no icons → symbols")
	wallet.free()
	var with_icons: WalletView = (load("res://scenes/wallet_view.tscn") as PackedScene).instantiate() as WalletView
	var assets: UiAssets = UiAssets.new()
	assets.coin_icon = _texture()
	assets.diamond_icon = _texture()
	with_icons.assets = assets
	with_icons.show_amounts(340, 25)
	assert_eq(with_icons.text, "340  25", "icons replace the symbols")
	with_icons.free()


func test_chest_image() -> void:
	var chest: GachaChest = (load("res://scenes/gacha_chest.tscn") as PackedScene).instantiate() as GachaChest
	chest.notification(Node.NOTIFICATION_READY)
	assert_false(chest.uses_art(), "drawn chest by default")
	chest.free()
	var art_chest: GachaChest = (load("res://scenes/gacha_chest.tscn") as PackedScene).instantiate() as GachaChest
	art_chest.theme_data = _theme_with_art()
	art_chest.notification(Node.NOTIFICATION_READY)
	assert_true(art_chest.uses_art(), "closed chest image")
	art_chest.free()
