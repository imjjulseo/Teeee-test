extends Logger
## 테스트 러너용 엔진 로거: 테스트 도중 발생한 **스크립트 오류**(null 접근, 잘못된 호출 등)를 센다.
## GDScript는 오류가 난 함수만 중단하고 호출한 쪽은 계속 실행하므로, 이 로거가 없으면
## 확인(assert_*) 전에 오류로 멈춘 테스트가 "통과"로 세어진다.
## push_error(의도적인 오류 알림)는 ERROR_TYPE_ERROR라서 세지 않는다.

var script_errors: int = 0
var last_error: String = ""

var _mutex: Mutex = Mutex.new()


func reset() -> void:
	_mutex.lock()
	script_errors = 0
	last_error = ""
	_mutex.unlock()


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type != ERROR_TYPE_SCRIPT:
		return
	_mutex.lock()
	script_errors += 1
	last_error = "%s (%s:%d in %s)" % [rationale if not rationale.is_empty() else code, file, line, function]
	_mutex.unlock()


func _log_message(_message: String, _error: bool) -> void:
	pass
