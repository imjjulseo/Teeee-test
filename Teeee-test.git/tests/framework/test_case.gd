extends RefCounted
## 테스트 베이스. tests/ 아래 test_*.gd가 이 스크립트를 상속하고 test_* 메서드를 정의한다.

var failures: PackedStringArray = PackedStringArray()


## 각 테스트 직전에 러너가 부른다. 필요하면 오버라이드.
func before_each() -> void:
	pass


## 각 테스트 직후에 러너가 부른다 (테스트가 스크립트 오류로 중단돼도 불린다). 필요하면 오버라이드.
## 전역 상태(SaveData.path_override, SafeArea.debug_insets)는 러너가 따로 확인·초기화한다.
func after_each() -> void:
	pass


func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		failures.append("expected true. %s" % message)


func assert_false(condition: bool, message: String = "") -> void:
	if condition:
		failures.append("expected false. %s" % message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("expected %s, got %s. %s" % [var_to_str(expected), var_to_str(actual), message])


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	if typeof(actual) == typeof(unexpected) and actual == unexpected:
		failures.append("expected value != %s. %s" % [var_to_str(unexpected), message])


func assert_near(actual: float, expected: float, tolerance: float = 1e-6, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		failures.append("expected %f (±%f), got %f. %s" % [expected, tolerance, actual, message])


func make_config() -> GameConfig:
	return GameConfig.new()
