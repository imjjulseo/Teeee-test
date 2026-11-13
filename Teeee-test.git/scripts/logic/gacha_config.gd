class_name GachaConfig
extends Resource
## 뽑기·다이아 상점·선택권 합성·광고 보상 수치 (기획서 8.4 · 8.5장). 팀 결정 전이라 HTML 값을 쓰는 (임시) 수치 (E15).
## ProgressionConfig.gacha로 참조한다 (레벨 보상 화면이 뽑기 단계·상점 개방도 보여 준다).

const Grade = CharacterData.Grade

## 뽑기 1회 가격 (코인). 머신 단계와 무관하게 고정 (팀 결정 11/04: ● 500, E25).
@export var price: int = 500
## 뽑기 머신 단계 (min_level 오름차순). 계정 레벨이 오르면 머신이 업그레이드되어 등급 확률이 바뀐다.
@export var tiers: Array[GachaTier] = []

@export_group("Diamond Shop")
## 등급 → 다이아 상점 가격.
@export var shop_prices: Dictionary[int, int] = {Grade.RARE: 80, Grade.HERO: 200, Grade.LEGEND: 450, Grade.MYTH: 900}
## 등급 → 다이아 상점에 그 등급이 열리는 계정 레벨.
@export var shop_levels: Dictionary[int, int] = {Grade.RARE: 1, Grade.HERO: 8, Grade.LEGEND: 20, Grade.MYTH: 30}

@export_group("Tickets")
## 같은 등급 선택권 이만큼 → 다음 등급 1장 (팀 결정 11/04: 5장, E24).
@export var fuse_count: int = 5

@export_group("Ad")
## 광고 보상 (자리만, E18): 1회 다이아, 하루 최대 횟수.
@export var ad_diamonds: int = 5
@export var ad_daily_max: int = 3

## 선택권 합성의 다음 등급 (없으면 -1).
const NEXT_GRADE: Dictionary[int, int] = {Grade.RARE: Grade.HERO, Grade.HERO: Grade.LEGEND, Grade.LEGEND: Grade.MYTH}


## level의 뽑기 단계 (표가 비어 있으면 null).
func tier_for(level: int) -> GachaTier:
	var found: GachaTier = null
	for tier: GachaTier in tiers:
		if level >= tier.min_level:
			found = tier
	if found == null and not tiers.is_empty():
		return tiers[0]
	return found


## level의 뽑기 단계 번호 (1부터).
func tier_number(level: int) -> int:
	return tiers.find(tier_for(level)) + 1


## level 다음에 오는 뽑기 단계 (없으면 null).
func next_tier(level: int) -> GachaTier:
	for tier: GachaTier in tiers:
		if tier.min_level > level:
			return tier
	return null


## 정확히 이 레벨에서 시작하는 뽑기 단계 (Lv1의 첫 단계 제외, 없으면 null). 레벨 보상 문구용.
func tier_starting_at(level: int) -> GachaTier:
	for tier: GachaTier in tiers:
		if tier.min_level == level and level > 1:
			return tier
	return null


## 뽑기 1회 가격 (단계와 무관).
func pull_price() -> int:
	return price


func shop_price(grade: int) -> int:
	return shop_prices.get(grade, 0)


func shop_level(grade: int) -> int:
	return shop_levels.get(grade, 1)


func is_shop_open(grade: int, level: int) -> bool:
	return shop_prices.has(grade) and level >= shop_level(grade)


func next_grade(grade: int) -> int:
	return NEXT_GRADE.get(grade, -1)


static func ensure_valid(config: GachaConfig) -> GachaConfig:
	if config == null:
		push_error("GachaConfig: config is null, using defaults")
		return GachaConfig.new()
	var errors: PackedStringArray = config.validate()
	if errors.is_empty():
		return config
	push_error("GachaConfig: invalid settings, using defaults instead: %s" % ", ".join(errors))
	return GachaConfig.new()


func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if price <= 0:
		errors.append("price must be > 0")
	var last_level: int = 0
	for tier: GachaTier in tiers:
		if tier == null or tier.min_level <= last_level:
			errors.append("tiers need increasing min_level")
			break
		if not is_equal_approx(tier.total_rate(), 100.0):
			errors.append("tier Lv%d rates must sum to 100 (%.2f)" % [tier.min_level, tier.total_rate()])
		last_level = tier.min_level
	if not tiers.is_empty() and tiers[0].min_level != 1:
		errors.append("the first tier must start at Lv1")
	if fuse_count <= 0:
		errors.append("fuse_count must be > 0")
	if ad_diamonds < 0 or ad_daily_max < 0:
		errors.append("ad values must be >= 0")
	return errors
