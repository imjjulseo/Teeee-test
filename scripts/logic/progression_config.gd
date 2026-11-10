class_name ProgressionConfig
extends Resource
## 진행·재화 수치 (기획서 8.2 · 8.4장). 팀 결정 전이라 HTML 값을 쓰는 (임시) 수치이므로 코드에 두지 않는다 (E15).
## 게임 규칙(GameConfig)과 따로 둔다 — 진행·재화 담당이 이 파일만 고친다.

@export_group("Experience Gain")
## 판 하나로 얻는 경험치 = exp_per_game + exp_per_point × 점수 (내림). 결과까지 간 판만 (튜토리얼·체험 판은 없음).
## (임시 — 팀 결정 11/04, 수치는 아직 확정 아님, E26)
@export var exp_per_game: int = 500
@export var exp_per_point: float = 0.25

@export_group("Experience Curve")
## 다음 레벨까지 필요한 경험치 (임시, E26). 레벨 제한 없음.
## curve_from_level 전: 직선 linear_base + linear_step × (Lv − 1)
## curve_from_level부터: 포물선 curve_base + curve_step × d + curve_square × d² (d = Lv − curve_from_level)
@export var curve_from_level: int = 20
@export var linear_base: int = 500
@export var linear_step: int = 100
@export var curve_base: int = 2400
@export var curve_step: int = 200
@export var curve_square: float = 10.0

@export_group("Level Rewards")
## 레벨이 오를 때마다 (매 레벨 같음, E26).
@export var level_up_coins: int = 100
@export var level_up_diamonds: int = 10
## 레벨 → 그 레벨에 오르면 받는 선택권 등급 (CharacterData.Grade). Lv10 영웅(B) · Lv20 전설(A) · Lv30 신화(S) (E26).
@export var ticket_levels: Dictionary[int, int] = {10: CharacterData.Grade.HERO, 20: CharacterData.Grade.LEGEND, 30: CharacterData.Grade.MYTH}

## 레벨 보상 화면: 적어도 이 레벨까지, 그리고 지금 레벨보다 이만큼 위까지 보인다.
@export var show_levels: int = 30
@export var show_ahead: int = 3

@export_group("Coins")
## 판 끝 코인 = ⌊점수 ÷ score_per_coin⌋ + 판에서 주운 금화.
@export var score_per_coin: int = 100

@export_group("Board Stages")
## 보드 단계 (Lv1부터). 마지막 단계가 본 게임이고, 그보다 높은 레벨도 마지막 단계.
@export var stages: Array[BoardStage] = []

@export_group("Revive")
## 부활 비용 (다이아). 부활 시간은 GameConfig.revive_time.
@export var revive_diamonds: int = 20

@export_group("Gacha")
## 뽑기·다이아 상점·선택권 합성 수치 (레벨 보상 문구에도 쓴다). 비어 있으면 기본값.
@export var gacha: GachaConfig


## level에서 다음 레벨까지 필요한 경험치 (직선 → curve_from_level부터 포물선, 내림).
func exp_to_next(level: int) -> int:
	var lv: int = maxi(level, 1)
	if lv < curve_from_level:
		return linear_base + linear_step * (lv - 1)
	var d: int = lv - curve_from_level
	return floori(curve_base + curve_step * d + curve_square * d * d)


## 결과까지 간 판 하나로 얻는 경험치 (점수가 음수면 0점으로).
func exp_for_score(score: int) -> int:
	return floori(exp_per_game + exp_per_point * maxi(score, 0))


## 판 끝 코인 (점수 몫 + 주운 금화).
func coins_for_run(score: int, picked_coins: int) -> int:
	return floori(float(maxi(score, 0)) / score_per_coin) + picked_coins


## level에 올랐을 때 받는 다이아 (매 레벨 같음).
func diamonds_for_level(_level: int) -> int:
	return level_up_diamonds


## level에 올랐을 때의 보상 (레벨 보상 화면에서 받는다, E36).
func level_up_for(level: int) -> RunRewards.LevelUp:
	return RunRewards.LevelUp.new(level, level_up_coins, diamonds_for_level(level), ticket_levels.get(level, -1))


## level의 보드 단계 (단계 표보다 높으면 마지막 단계). 표가 비어 있으면 null.
func stage_for_level(level: int) -> BoardStage:
	if stages.is_empty():
		return null
	return stages[clampi(level, 1, stages.size()) - 1]


## level의 보드 단계 번호 (1부터, 마지막 단계에서 멈춘다).
func stage_number(level: int) -> int:
	return clampi(level, 1, maxi(stages.size(), 1))


## level 다음 레벨에서 바뀌는 보드 단계 설명. 이미 마지막 단계면 "".
func next_stage_description(level: int) -> String:
	return stages[level].description if level >= 1 and level < stages.size() else ""


## 레벨 보상 화면의 한 레벨 보상 문구 (8.1장): 보드 단계, 레벨업 코인·다이아, 선택권, 뽑기 단계, 다이아 상점 등급 개방.
func rewards_for_level(level: int) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if level == 1 and not stages.is_empty():
		lines.append("시작 보드 · %s" % stages[0].description)
	elif level > 1 and level <= stages.size():
		lines.append("보드 업그레이드 · %s" % stages[level - 1].description)
	if level > 1:
		lines.append("● %d" % level_up_coins)
		lines.append("◆ %d" % diamonds_for_level(level))
	if ticket_levels.has(level):
		lines.append("%s 선택권" % CharacterData.GRADE_NAMES[ticket_levels[level]])
	if gacha == null:
		return lines
	var tier: GachaTier = gacha.tier_starting_at(level)
	if tier != null:
		lines.append("뽑기 머신 업그레이드 · 확률 상승")
	for grade: int in gacha.shop_levels:
		if level > 1 and gacha.shop_level(grade) == level:
			lines.append("상점 %s 열림" % CharacterData.GRADE_NAMES[grade])
	return lines


## 레벨 보상 화면에 보일 마지막 레벨 (최소 show_levels, 지금 레벨 + show_ahead).
func levels_to_show(current: int) -> int:
	return maxi(show_levels, current + show_ahead)


## 잘못된 값이면 오류를 알리고 기본값으로 (GameConfig.ensure_valid와 같은 방식, 배포 빌드에서도).
## 뽑기 수치(gacha)도 함께 검사하고, 없으면 빈 기본값(뽑기 단계 없음)을 넣는다.
static func ensure_valid(config: ProgressionConfig) -> ProgressionConfig:
	var valid: ProgressionConfig = config
	if config == null:
		push_error("ProgressionConfig: config is null, using defaults")
		valid = ProgressionConfig.new()
	elif not config.validate().is_empty():
		push_error("ProgressionConfig: invalid settings, using defaults instead: %s" % ", ".join(config.validate()))
		valid = ProgressionConfig.new()
	valid.gacha = GachaConfig.ensure_valid(valid.gacha) if valid.gacha != null else GachaConfig.new()
	return valid


func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if score_per_coin <= 0:
		errors.append("score_per_coin must be > 0")
	if exp_per_game < 0 or exp_per_point < 0.0:
		errors.append("exp gain must be >= 0")
	if curve_from_level < 1 or linear_base <= 0 or linear_step < 0 or curve_base <= 0 or curve_step < 0 or curve_square < 0.0:
		errors.append("exp curve needs curve_from_level >= 1, bases > 0 and non-negative steps")
	if revive_diamonds < 0:
		errors.append("revive_diamonds must be >= 0")
	return errors
