extends "res://tests/smoke/smoke_base.gd"
## 디자인 이미지 자리 확인: 모든 자리에 임시 이미지(icon.svg)를 메모리에서 넣고 화면마다 실제로 보이는지·배치가 깨지지 않는지 본다.
## 인트로 로고 → 메뉴 지갑 아이콘 → 게임 판(블록·플레이어·씨앗·금화·족보 점·HUD 코인 아이콘·발동 섬광) → 캐릭터 화면 카드·시트 →
## 상점 상자(닫힘 → 열림)·결과 카드. 스크린샷은 user://smoke_shots/smoke_art_*.png

const DUMMY: String = "res://icon.svg"

## 메모리에서 바꾼 리소스를 쥐고 있어야 씬이 바뀌어도 캐시에서 같은 인스턴스를 쓴다.
var _kept: Array[Resource] = []


func _setup() -> void:
	var art: Texture2D = load(DUMMY) as Texture2D
	var theme: BoardTheme = load("res://resources/board_theme.tres") as BoardTheme
	theme.block_textures = [art, art, art, art] as Array[Texture2D]
	theme.seed_texture = art
	theme.coin_texture = art
	theme.player_texture = art
	theme.ability_flash_texture = art
	theme.effect_background_texture = art
	theme.chest_closed_texture = art
	theme.chest_open_texture = art
	for kind: int in BoardMark.Kind.values():
		theme.mark_textures[kind] = art
	for character: CharacterData in (load("res://resources/character_roster.tres") as CharacterRoster).characters:
		character.portrait = art
	var assets: UiAssets = load("res://resources/ui_assets.tres") as UiAssets
	_kept = [theme, load("res://resources/character_roster.tres"), assets] as Array[Resource]
	assets.logo = art
	assets.coin_icon = art
	assets.diamond_icon = art
	for slot: StringName in [&"shop_icon", &"achievements_icon", &"puzzle_icon", &"options_icon", &"swipe_hint", &"back_icon", &"left_arrow", &"right_arrow", &"lock_icon", &"star_on", &"star_off"]:
		assets.set(slot, art)
	var progress: ProgressStore = ProgressStore.new()
	progress.unlock(&"clock")
	progress.add_currency(1000, 30)
	CharacterStore.new().select(&"clock")
	change_scene_to_file("res://scenes/intro.tscn")


func _tick() -> void:
	match step:
		0:
			if in_scene("Intro", 0.4):
				expect((node("%LogoImage") as Control).visible and not (node("%Logo") as Control).visible, "logo image")
				shot("intro")
				change_scene_to_file("res://scenes/main_menu.tscn")
				next_step()
		1:
			if in_scene("MainMenu", 0.4):
				expect((node("%TopBar/%WalletLabel") as WalletView).text == "1000  30", "wallet icons (%s)" % (node("%TopBar/%WalletLabel") as WalletView).text)
				expect((node("%BottomNav/%ShopButton/Icon") as Control).visible and not (node("%BottomNav/%ShopButton/Label") as Control).visible, "nav icon replaces the text")
				shot("menu")
				change_scene_to_file("res://scenes/main.tscn")
				next_step()
		2:
			if playing(0.5):
				expect((node("Hud/%CoinLabel") as Label).text == "0" and (node("Hud/%CoinIcon") as Control).visible, "HUD coin icon")
				var board: Board = session().board
				board.teleport_player(board.center())
				prepare_match_above(0)
				flow().request_move(Vector2i.UP)  # 매치 → 씨앗
				session().prime_ability_condition()
				next_step()
		3:
			if step_time > 0.4:
				session().trigger_ability()  # 섬광·배너·배경 효과
				next_step()
		4:
			if step_time > 0.15:
				shot("game")
				change_scene_to_file("res://scenes/character_select.tscn")
				next_step()
		5:
			if in_scene("CharacterSelect", 0.5):
				var page: CharacterInfo = (current_scene as CharacterSelect).carousel().current_page()
				expect((page.get_node("%InfoBlock/%Portrait") as Control).visible, "page portrait")
				shot("characters")
				next_step()
		6:
			next_step()
		7:
			if step_time > 0.1:
				shot("sheet")
				change_scene_to_file("res://scenes/shop.tscn")
				next_step()
		8:
			if in_scene("Shop", 0.5):
				expect((node("%Chest") as GachaChest).uses_art(), "chest image")
				shot("shop")
				click_control(node("%Chest"))
				next_step()
		9:
			if (node("%Reveal") as Control).visible and step_time > 2.5:
				expect((node("%Reveal").get_node("%Portrait") as Control).visible, "reveal portrait")
				shot("reveal")
				change_scene_to_file("res://scenes/puzzle_menu.tscn")
				next_step()
			elif step_time > 8.0:
				fail("chest did not open")
				finish()
		10:
			if in_scene("PuzzleMenu", 0.5):
				var locked: PuzzleBoardButton = (current_scene as PuzzleMenuScreen).buttons()[1]
				expect((locked.get_node("LockOverlay/LockIcon") as Control).visible, "lock image")
				shot("puzzles")
				finish()
