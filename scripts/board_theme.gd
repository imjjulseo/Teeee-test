class_name BoardTheme
extends Resource
## 보드 시각 테마 (임시 그래픽). 색 팔레트, 크기, 연출 값을 데이터로 분리한다.

@export_group("Colors")
## 색 ID 순서의 블록 색 (E16: 0 노랑 · 1 빨강 · 2 파랑 · 3 초록, 기획서 7.3 팔레트).
@export var block_colors: PackedColorArray = PackedColorArray([
	Color("f0a830"),  # 0 yellow
	Color("e2556e"),  # 1 red
	Color("5b8def"),  # 2 blue
	Color("6fbf5b"),  # 3 green
])
## 색 ID 순서의 문양 (GlyphView.Shape 값). 색만으로 구분하지 않도록 색마다 다르게 둔다 (7.3).
@export var block_glyphs: PackedInt32Array = PackedInt32Array([
	GlyphView.Shape.CIRCLE,  # 0 yellow
	GlyphView.Shape.SQUARE,  # 1 red
	GlyphView.Shape.DIAMOND,  # 2 blue
	GlyphView.Shape.TRIANGLE,  # 3 green
])
## 문양 색 (블록 위에 반투명하게 겹친다).
@export var glyph_color: Color = Color(0, 0, 0, 0.35)
@export var player_fill: Color = Color("1d1f26")
@export var player_border: Color = Color("ffffff")
## 씨앗 칸 바탕색. 자랄 색은 드러내지 않는다.
@export var seed_base_color: Color = Color(1, 1, 1, 0.06)
## 씨앗 자람 표시(중앙에서 바깥으로 차오르는 사각형) 색.
@export var seed_fill_color: Color = Color(1, 1, 1, 0.3)
@export var empty_color: Color = Color(0, 0, 0, 0)
## 금화 표시 색 (기획서 4.4장).
@export var coin_color: Color = Color("ffd23f")

@export_group("Layout")
@export var cell_size: float = 64.0
@export var cell_gap: float = 4.0
@export var player_border_width: float = 5.0

@export_group("Recipe")
## 족보 칸 하나의 크기(px).
@export var recipe_step_size: float = 38.0
## 이미 제거한 족보 칸의 불투명도 (HTML: 모은 칸은 또렷하게 = 1).
@export_range(0.0, 1.0) var recipe_done_alpha: float = 1.0
## 아직 모으지 않은 칸의 불투명도 (HTML .rc.tint .dot = .4). 다음 칸만 또렷하게 + 흰 테두리.
@export_range(0.0, 1.0) var recipe_pending_alpha: float = 0.4
## 족보 카드 바탕(HTML --panel)과 다음 색을 섞는 비율 (바탕 36%, 테두리 80%), 카드 모서리·테두리 두께, 다음 칸 흰 고리 두께.
@export var recipe_card_bg: Color = Color(0.0745098, 0.176471, 0.211765, 1)
@export_range(0.0, 1.0) var recipe_tint: float = 0.36
@export_range(0.0, 1.0) var recipe_border_tint: float = 0.8
@export var recipe_card_radius: int = 14
@export var recipe_card_border: int = 3
@export var recipe_next_ring: int = 5
## 다음에 제거할 칸의 강조 테두리.
@export var recipe_next_border: Color = Color("ffffff")
## 족보 박스가 4개(능력 조건 포함)일 때의 칸 크기(px). 화면 폭에 맞추기 위해 줄인다.
@export var recipe_step_size_compact: float = 30.0
## 시계공 "정지" 중 남은 시간 표시 색.
@export var hud_time_stop_color: Color = Color("7fd6ff")
## 족보 완성 시 박스가 커졌다 돌아오는 비율.
@export var recipe_complete_pop_scale: float = 1.15

@export_group("HUD")
@export var hud_time_color: Color = Color("ffffff")
## 남은 시간 경고 색과, 매 초 커졌다 돌아오는 비율/시간.
@export var hud_warning_color: Color = Color("ff5a4a")
@export var hud_warning_pulse_scale: float = 1.25
@export var hud_warning_pulse_duration: float = 0.25
## 점수 표시가 실제 점수를 따라가는 속도 (초당 남은 차이의 비율).
@export var score_count_speed: float = 12.0
## 떠오르는 숫자("+2.5", "+10")가 올라가는 거리(px)와 시간(초).
@export var float_rise: float = 40.0
@export var float_duration: float = 0.8
## 족보 완성 "+N" 팝업이 떠오르는 거리(px)와 시간(초).
@export var score_popup_rise: float = 60.0
@export var score_popup_duration: float = 0.9

@export_group("Feedback")
## 교환 시 밀려나는 블록이 작아지는 비율 (두 블록이 서로 통과하지 않고 교환이 보이도록).
@export_range(0.1, 1.0) var swap_block_scale: float = 0.7
## 매치 강조 시 4칸이 커졌다 돌아오는 비율 (시간은 GameConfig.clear_animation_time).
@export var clear_pop_scale: float = 1.2
## 리필 생성 시 팝 비율과 시간(초).
@export var refill_pop_scale: float = 0.6
@export var refill_pop_duration: float = 0.15
## 매치 때 판 전체가 흔들리는 거리(px)와 시간(초).
@export var match_shake_distance: float = 3.0
@export var match_shake_duration: float = 0.2
## 매치 파편: 칸마다 개수, 퍼지는 속도(px/초), 크기(px), 사라지는 시간(초).
@export var burst_count: int = 7
@export var burst_speed: float = 220.0
@export var burst_size: float = 7.0
@export var burst_lifetime: float = 0.45
## 벽 입력 흔들림 거리(px)와 시간(초).
@export var wall_shake_distance: float = 6.0
@export var wall_shake_duration: float = 0.12

@export_group("Ability")
## 캐릭터 카드 테두리 두께(px). 색은 캐릭터 색.
@export var ability_border_width: int = 4
## 발동 섬광: 화면 전체에 캐릭터 색을 이 불투명도로 덮었다가 사라지는 시간(초).
@export_range(0.0, 1.0) var ability_flash_alpha: float = 0.35
@export var ability_flash_duration: float = 0.6
## 발동 배너("촉진!" + 설명): 처음 크기 배율, 보이는 시간(초).
@export var ability_banner_start_scale: float = 2.3
@export var ability_banner_duration: float = 1.0
## 배경 효과: 가장 진할 때 불투명도, 켜고 끌 때 따라가는 속도(초당 비율).
@export_range(0.0, 1.0) var effect_alpha: float = 0.3
@export var effect_fade_speed: float = 10.0
## 배경 효과가 끝나기 몇 초 전부터 깜빡이는지, 깜빡임 빠르기(시작 → 끝, Hz) (5.2장 공통 규칙).
@export var effect_blink_window: float = 3.0
@export var effect_blink_start_hz: float = 2.0
@export var effect_blink_end_hz: float = 8.0
## 씨앗이 자랄 색을 보여 줄 때(예지안) 바탕·문양의 불투명도.
@export_range(0.0, 1.0) var seed_reveal_alpha: float = 0.35
## 수선사 끈: 선 두께(px), 색, 시작 칸 원 크기(칸 대비).
@export var trail_width: float = 6.0
@export var trail_color: Color = Color("2fcf74")
@export var trail_start_radius: float = 0.32
## 상시형 캐릭터 카드 배경 (족보가 없어 다음 색이 없다).
@export var passive_card_color: Color = Color(1, 1, 1, 0.08)
## 판 위 능력 표시: 선 두께(px), 탐험 구역 점선 길이(px)와 색, 깃발 색(가야 할 깃발 / 준비된 깃발 / 다음 깃발).
@export var mark_line_width: float = 4.0
@export var mark_dash_length: float = 10.0
@export var mark_zone_color: Color = Color(1, 1, 1, 0.75)
@export var mark_flag_color: Color = Color(1, 1, 1, 0.7)
@export var mark_flag_ready_color: Color = Color("ffd23f")
@export var mark_flag_next_color: Color = Color(1, 1, 1, 0.25)
## 곧 바뀔 칸 예고 테두리 색 (방화광: 불이 번질 칸).
@export var mark_warn_color: Color = Color("ff8a2a")

@export_group("Puzzle")
## 블럭 모으기 안내: 모을 블록 테두리, 목표 가운데·빈 자리·모인 자리, 설 칸, 당길 블록, 화살표.
@export var puzzle_target_color: Color = Color(1, 1, 1, 0.9)
@export var puzzle_goal_color: Color = Color(1, 0.823529, 0.247059, 0.35)
@export var puzzle_filled_color: Color = Color("6fbf5b")
@export var puzzle_stand_color: Color = Color("8fe3ff")
@export var puzzle_pull_color: Color = Color("ffd23f")
@export var puzzle_arrow_color: Color = Color(1, 1, 1, 1)
## 퍼즐 안내 빛 (HTML tuthl · tpull · tarr): 맥박 주기(초), 모을 블록 빛·밝히기, 당길 블록 빛 진하기, 화살표 깜빡임 주기.
@export var glow_period: float = 1.2
@export var target_glow_color: Color = Color(1, 1, 1, 0.45)
@export var glow_brighten: Color = Color(1, 1, 1, 0.12)
@export var pull_glow_alpha: float = 0.6
@export var arrow_period: float = 0.9
## 튜토리얼 첫 판 손가락 안내 (HTML tswipe): 한 번(초), 칸 대비 크기, 원·테두리 색.
@export var swipe_period: float = 1.4
@export var swipe_size: float = 0.46
@export var swipe_color: Color = Color(1, 1, 1, 0.85)
@export var swipe_halo: Color = Color(1, 1, 1, 0.25)

@export_group("Collection")
## 등급 색 (CharacterData.Grade 순서: 기본·희귀·영웅·전설·신화·히든). 캐릭터 카드·상점·뽑기 연출.
@export var grade_colors: Array[Color] = [Color("8faab2"), Color("5b8def"), Color("b07cd6"), Color("ffd23f"), Color("ff5c8a"), Color("3fe0c5")]
## 뽑기 상자 흔들림 시간(초): 결과의 최고 등급별 (Grade 순서). 효과 줄이기면 0.
@export var chest_charge_times: PackedFloat32Array = PackedFloat32Array([0.45, 0.6, 0.85, 1.15, 1.15, 1.15])
## 상자가 열린 뒤 카드가 나오기까지(초), 카드 뒤집기(초).
@export var chest_open_time: float = 0.7
@export var card_flip_time: float = 0.3

@export_group("Art")
## 디자인 이미지 자리 (한 장 이미지). 비어 있으면 지금처럼 색·문양을 코드로 그린다.
## 색 ID 순서(0 노랑 · 1 빨강 · 2 파랑 · 3 초록)의 블록 이미지 — 문양까지 그려진 이미지. 판 칸·족보 점에 쓴다.
## 능력이 블록 색을 바꾸는 동안(색약·뱀파이어·레트로 흑백)은 색·문양 그림으로 돌아간다.
@export var block_textures: Array[Texture2D] = []
## 씨앗(자라는 칸): 가운데서 자람 진행도만큼 커진다.
@export var seed_texture: Texture2D
## 금화 (블록 오른쪽 위).
@export var coin_texture: Texture2D
## 플레이어 (캐릭터 이미지 CharacterData.portrait가 없을 때).
@export var player_texture: Texture2D
## 판 위 표시 (BoardMark.Kind 값 → 이미지): 깃발·구역·예고·퍼즐 안내. 화살표(ARROW)는 오른쪽을 향한 이미지를 돌려 쓴다. 길(PATH)은 선이라 제외.
@export var mark_textures: Dictionary[int, Texture2D] = {}
## 능력 발동 섬광 (화면 전체, 캐릭터 색으로 물든다).
@export var ability_flash_texture: Texture2D
## 능력 지속 효과 배경 (판 뒤 화면 전체, 효과 색으로 물든다).
@export var effect_background_texture: Texture2D
## 뽑기 상자: 닫힌 모습 / 열린 모습.
@export var chest_closed_texture: Texture2D
@export var chest_open_texture: Texture2D


func grade_color(grade: int) -> Color:
	return grade_colors[grade] if grade >= 0 and grade < grade_colors.size() else Color.WHITE


func color_for(color_id: int) -> Color:
	if color_id < 0 or color_id >= block_colors.size():
		return empty_color
	return block_colors[color_id]


## 능력의 표시 방식(style)을 적용한 칠할 색 (색약: 합친 색, 레트로: 흑백). style이 null이면 color_for와 같다.
func display_color(color_id: int, style: DisplayStyle) -> Color:
	if style == null:
		return color_for(color_id)
	var color: Color = color_for(style.fill_color_id(color_id))
	if style.monochrome:
		var gray: float = color.get_luminance()
		color = Color(gray, gray, gray, color.a)
	return color


## 판 칸·족보 점에 쓸 블록 이미지. 이미지가 없거나 능력이 블록 색을 바꾸는 중(style)이면 null → 색·문양 그림.
## (색을 바꾸는 동안은 모든 블록을 같은 방식으로 그려 이미지와 그림이 섞이지 않게 한다.)
func block_art(color_id: int, style: DisplayStyle = null) -> Texture2D:
	if color_id < 0 or color_id >= block_textures.size():
		return null
	if style != null and (style.monochrome or not style.color_alias.is_empty()):
		return null
	return block_textures[color_id]


## 판 위 표시 이미지 (없으면 null → 코드로 그림).
func mark_art(kind: int) -> Texture2D:
	return mark_textures.get(kind, null)


func glyph_for(color_id: int) -> GlyphView.Shape:
	if color_id < 0 or color_id >= block_glyphs.size():
		return GlyphView.Shape.NONE
	return block_glyphs[color_id] as GlyphView.Shape
