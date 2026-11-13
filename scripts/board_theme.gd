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
@export var cell_size: float = 96.0
@export var cell_gap: float = 6.0
@export var player_border_width: float = 7.5

@export_group("Recipe")
## 족보 칸 하나의 크기(px).
@export var recipe_step_size: float = 57.0
## 이미 제거한 족보 칸의 불투명도 (HTML: 모은 칸은 또렷하게 = 1).
@export_range(0.0, 1.0) var recipe_done_alpha: float = 1.0
## 아직 모으지 않은 칸의 불투명도 (HTML .rc.tint .dot = .4). 다음 칸만 또렷하게 + 흰 테두리.
@export_range(0.0, 1.0) var recipe_pending_alpha: float = 0.4
## 족보 카드 바탕(HTML --panel)과 다음 색을 섞는 비율 (바탕 36%, 테두리 80%), 카드 모서리·테두리 두께, 다음 칸 흰 고리 두께.
@export var recipe_card_bg: Color = Color(0.0745098, 0.176471, 0.211765, 1)
@export_range(0.0, 1.0) var recipe_tint: float = 0.36
@export_range(0.0, 1.0) var recipe_border_tint: float = 0.8
@export var recipe_card_radius: int = 21
@export var recipe_card_border: int = 4
@export var recipe_next_ring: int = 7
## 다음에 제거할 칸의 강조 테두리.
@export var recipe_next_border: Color = Color("ffffff")
## 족보 박스가 4개(능력 조건 포함)일 때의 칸 크기(px). 화면 폭에 맞추기 위해 줄인다.
@export var recipe_step_size_compact: float = 45.0
## 족보 카드 안 여백(px).
@export var recipe_card_padding: int = 15
## HUD 캐릭터 줄 (족보 카드 아래): 바탕을 캐릭터 색으로 물들이는 비율, 지나가는 빛 띠 진하기·주기(초, HTML sheen 3.8),
## 튜토리얼이 가리킬 때 맥박 주기(초, HTML ctPulse 1.2)·빛 크기(px), 발동 때 커지는 배율·밝기·시간(HTML chrBurst 0.6초).
@export_range(0.0, 1.0) var character_row_tint: float = 0.26
@export_range(0.0, 1.0) var character_row_sheen_alpha: float = 0.3
@export var character_row_sheen_period: float = 3.8
@export var character_row_pulse_period: float = 1.2
@export var character_row_pulse_size: float = 30.0
@export var character_burst_scale: float = 1.08
@export var character_burst_brightness: float = 1.4
@export var character_burst_duration: float = 0.6
## 시계공 "정지" 중 남은 시간 표시 색.
@export var hud_time_stop_color: Color = Color("7fd6ff")
## 캐릭터 카드 발동 시 박스가 커졌다 돌아오는 비율.
@export var recipe_complete_pop_scale: float = 1.15
## 족보 칸이 채워질 때 (HTML dotHit: 1.7배 · brightness 2 → 원래, 0.32초 cubic-bezier(.2,.9,.3,1.4)).
@export var dot_hit_scale: float = 1.7
@export var dot_hit_brightness: float = 2.0
@export var dot_hit_duration: float = 0.32
@export var dot_hit_curve: Vector4 = Vector4(0.2, 0.9, 0.3, 1.4)
## 족보 완성: 잠깐 뒤(card_break_delay) 카드가 커지며 밝아지다 작아지며 위로 빠지고(HTML cardBreak 0.2초 ease-in),
## 새 카드가 위에서 내려온다(HTML cardIn 0.24초). 거리는 화면 px.
## 깨짐: 30%에 peak 배율·밝기, 끝에 end 배율·밝기·투명 (HTML cardBreak 1.1 · 1.9 → 0.55 · 2.6).
## 등장: 위로 drop만큼, enter 배율·투명에서 시작 (HTML cardIn -18 CSS px · 0.82).
@export var card_break_delay: float = 0.06
@export var card_break_duration: float = 0.2
@export var card_break_peak_scale: float = 1.1
@export var card_break_brightness: float = 1.9
@export var card_break_end_scale: float = 0.55
@export var card_break_end_brightness: float = 2.6
@export var card_break_rise: float = 20.5
@export var card_enter_duration: float = 0.24
@export var card_enter_drop: float = 48.0
@export var card_enter_scale: float = 0.82
@export var card_enter_curve: Vector4 = Vector4(0.2, 0.9, 0.3, 1.35)

@export_group("HUD")
@export var hud_time_color: Color = Color("ffffff")
## 남은 시간 경고 색과, 매 초 커졌다 돌아오는 비율/시간.
@export var hud_warning_color: Color = Color("ff5a4a")
@export var hud_warning_pulse_scale: float = 1.25
@export var hud_warning_pulse_duration: float = 0.25
## 점수 표시가 실제 점수를 따라가는 속도 (초당 남은 차이의 비율).
@export var score_count_speed: float = 12.0
## 점수·시간·코인 숫자가 바뀔 때 커졌다 돌아오는 비율과 시간 (HTML bump: 1.22배 → 0.28초 ease-out, 왼쪽 아래 기준).
@export var bump_scale: float = 1.22
@export var bump_duration: float = 0.28
## 떠오르는 숫자(HTML rise)와 날아가는 숫자(HTML fly: 족보 점수 → 점수, 금화 → 코인)의 시간(초).
@export var float_duration: float = 0.8
@export var fly_duration: float = 0.75
## 떠오르는 글자 크기(px, 1080 기준 = HTML CSS px × 2.67). 매치 시간 "+2.5"와 그 색.
@export var float_time_size: float = 40.0
@export var float_time_color: Color = Color("e6f0f2")
<<<<<<< HEAD
## 금화 "+10": 기본 크기 + 연속 1번마다 커지는 크기(최대 4번). "코인 N연속!" 크기·커지는 크기, 금화 위로 띄우는 거리.
=======
## 금화 "+10": 기본 크기 + 연속 1번마다 커지는 크기(최대 4번). "금화 N연속!" 크기·커지는 크기, 금화 위로 띄우는 거리.
>>>>>>> Choi
@export var float_coin_size: float = 64.0
@export var float_coin_size_step: float = 10.7
@export var float_chain_size: float = 53.3
@export var float_chain_size_step: float = 8.0
@export var float_chain_offset: float = 90.7
## 족보 완성 "+점수": 기본 크기 + 난이도(길이 + 반복) 1마다 커지는 크기(최대 4). 족보 밖 점수(피버 정산 등) 크기.
@export var float_recipe_size: float = 53.3
@export var float_recipe_size_step: float = 8.0
@export var float_bonus_size: float = 106.7
## 족보 카드가 깨질 때 색마다 터지는 파편 (개수 · 속도 px/초 · 크기 px).
@export var card_burst_count: int = 9
@export var card_burst_speed: float = 853.0
@export var card_burst_size: float = 16.0
## 튜토리얼 칭찬 (HTML tutCheer: Good · Great! · Awesome!): 등급별 크기·색, 플레이어 칸 위로 띄우는 거리,
## 등급별 파편(Great! 이상) 개수·속도와 크기, 등급 없는 칭찬 글의 크기·색.
@export var cheer_sizes: PackedFloat32Array = PackedFloat32Array([58.7, 69.3, 80.0])
@export var cheer_colors: Array[Color] = [Color("9fe3c9"), Color("8fd3ff"), Color("ffd23f")]
@export var cheer_offset: float = 80.0
@export var cheer_burst_counts: PackedInt32Array = PackedInt32Array([0, 9, 18])
@export var cheer_burst_speeds: PackedFloat32Array = PackedFloat32Array([0.0, 587.0, 800.0])
@export var cheer_burst_size: float = 10.7
@export var cheer_text_size: float = 64.0
@export var cheer_text_color: Color = Color("ffd23f")

@export_group("Feedback")
## 이동 미끄러짐 곡선 (HTML .blk transition cubic-bezier(.3,.8,.4,1), 시간은 GameConfig.move_animation_time).
@export var move_curve: Vector4 = Vector4(0.3, 0.8, 0.4, 1.0)
## 블록이 생기거나 색이 바뀔 때 번쩍임 (HTML pop: brightness 2.1 · saturate .4 → 원래, 0.26초 ease-out).
@export var pop_brightness: float = 2.1
@export var pop_saturation: float = 0.4
@export var pop_duration: float = 0.26
## 매치로 깨진 블록이 커지며 밝아지고 사라짐 (HTML .gone: 1.3배 · brightness 1.9 · 투명, 시간은 GameConfig.clear_animation_time).
@export var clear_scale: float = 1.3
@export var clear_brightness: float = 1.9
## 퍼즐을 깔 때 내 칸에서 가까운 칸부터 튀어나옴 (HTML flipIn: 0.2배·투명 → 1, 0.28초, 거리 1칸마다 0.055초 늦게).
@export var stamp_start_scale: float = 0.2
@export var stamp_duration: float = 0.28
@export var stamp_delay_step: float = 0.055
@export var stamp_curve: Vector4 = Vector4(0.2, 0.9, 0.3, 1.3)
## 매치 때 판 전체가 흔들리는 거리(화면 px)와 시간(초) (HTML shake: 2 CSS px, 0.2초).
@export var match_shake_distance: float = 5.33
@export var match_shake_duration: float = 0.2
## 매치 파편 (HTML burst): 칸마다 개수, 기준 속도(화면 px/초)와 그 배율 범위, 위로 뜨는 비율, 중력(px/초²),
## 1/60초마다 가로 속도에 곱하는 값, 크기(px), 수명 범위(초).
@export var burst_count: int = 7
@export var burst_speed: float = 587.0
@export var burst_speed_min: float = 0.35
@export var burst_speed_max: float = 1.15
@export var burst_lift: float = 0.35
@export var burst_gravity: float = 2133.0
@export var burst_drag: float = 0.985
@export var burst_size: float = 13.3
@export var burst_life_min: float = 0.4
@export var burst_life_max: float = 0.8
## 벽 입력 때 플레이어가 살짝 튕기는 거리(화면 px)와 시간(초) (HTML nudge: 6 CSS px, 0.17초 ease-out).
@export var wall_shake_distance: float = 16.0
@export var wall_shake_duration: float = 0.17

@export_group("Ability")
## 캐릭터 카드 테두리 두께(px). 색은 캐릭터 색.
@export var ability_border_width: int = 6
## 발동 섬광: 화면 전체에 캐릭터 색을 이 불투명도로 덮었다가 사라지는 시간(초).
@export_range(0.0, 1.0) var ability_flash_alpha: float = 0.35
@export var ability_flash_duration: float = 0.6
## 발동 배너("촉진!" + 설명): 처음 크기 배율, 보이는 시간(초).
@export var ability_banner_start_scale: float = 2.3
@export var ability_banner_duration: float = 1.0
## 배경 효과: 가장 진할 때 불투명도, 켜고 끌 때 따라가는 속도(초당 비율).
@export_range(0.0, 1.0) var effect_alpha: float = 0.3
@export var effect_fade_speed: float = 10.0
## 맥박치는 배경 효과(뱀파이어)가 가장 진할 때 더하는 비율.
@export var effect_pulse_boost: float = 0.8
## 배경 효과가 끝나기 몇 초 전부터 깜빡이는지, 깜빡임 빠르기(시작 → 끝, Hz) (5.2장 공통 규칙).
@export var effect_blink_window: float = 3.0
@export var effect_blink_start_hz: float = 2.0
@export var effect_blink_end_hz: float = 8.0
## 씨앗이 자랄 색을 보여 줄 때(예지안) 바탕·문양의 불투명도.
@export_range(0.0, 1.0) var seed_reveal_alpha: float = 0.35
## 수선사 끈: 선 두께(px), 색, 시작 칸 원 크기(칸 대비).
@export var trail_width: float = 9.0
@export var trail_color: Color = Color("2fcf74")
@export var trail_start_radius: float = 0.32
## 상시형 캐릭터 카드 배경 (족보가 없어 다음 색이 없다).
@export var passive_card_color: Color = Color(1, 1, 1, 0.08)
## 판 위 능력 표시: 선 두께(px), 탐험 구역 점선 길이(px)와 색, 깃발 색(가야 할 깃발 / 준비된 깃발 / 다음 깃발).
@export var mark_line_width: float = 6.0
@export var mark_dash_length: float = 15.0
@export var mark_zone_color: Color = Color(1, 1, 1, 0.75)
@export var mark_flag_color: Color = Color(1, 1, 1, 0.7)
@export var mark_flag_ready_color: Color = Color("ffd23f")
@export var mark_flag_next_color: Color = Color(1, 1, 1, 0.25)
## 곧 바뀔 칸 예고 테두리 색 (방화광: 불이 번질 칸).
@export var mark_warn_color: Color = Color("ffb04a")
## 불 번짐 예고 칸이 번갈아 바뀌는 색 (HTML emberWarn #FF4A2A).
@export var mark_warn_hot_color: Color = Color("ff4a2a")

@export_group("Puzzle")
<<<<<<< HEAD
## 블록 모으기 안내: 모을 블록 테두리, 목표 가운데·빈 자리·모인 자리, 설 칸, 당길 블록, 화살표.
=======
## 블럭 모으기 안내: 모을 블록 테두리, 목표 가운데·빈 자리·모인 자리, 설 칸, 당길 블록, 화살표.
>>>>>>> Choi
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
## 결과 화면: 보유 코인이 차오르는 시간, 경험치 바 한 칸을 다 채우는 시간 (E36).
## 점수가 0부터 차오르는 시간 (E38).
@export var result_score_time: float = 0.7
@export var result_coin_time: float = 0.9
@export var result_exp_time: float = 0.8

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


## CSS filter: brightness(b) saturate(s)를 base 색에 건 결과를 내는 modulate 값 (채널별 배율, 1보다 클 수 있다).
## 색을 모르는 이미지·그림 칸은 밝기 배율만 (Color(b, b, b)). HTML pop·dotHit·cardBreak 번쩍임에 쓴다.
static func filter_modulate(base: Color, brightness: float, saturation: float = 1.0) -> Color:
	var lit: Color = Color(minf(base.r * brightness, 1.0), minf(base.g * brightness, 1.0), minf(base.b * brightness, 1.0))
	# CSS saturate 행렬 (W3C Filter Effects).
	var s: float = saturation
	var r: float = (0.213 + 0.787 * s) * lit.r + (0.715 - 0.715 * s) * lit.g + (0.072 - 0.072 * s) * lit.b
	var g: float = (0.213 - 0.213 * s) * lit.r + (0.715 + 0.285 * s) * lit.g + (0.072 - 0.072 * s) * lit.b
	var b: float = (0.213 - 0.213 * s) * lit.r + (0.715 - 0.715 * s) * lit.g + (0.072 + 0.928 * s) * lit.b
	var out: Color = Color(clampf(r, 0.0, 1.0), clampf(g, 0.0, 1.0), clampf(b, 0.0, 1.0))
	return Color(_ratio(out.r, base.r, brightness), _ratio(out.g, base.g, brightness), _ratio(out.b, base.b, brightness))


static func _ratio(target: float, base: float, fallback: float) -> float:
	return target / base if base > 0.02 else fallback
