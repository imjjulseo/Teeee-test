extends RefCounted
## 테스트용: 씬 파일(.tscn)에 적힌 signal 연결을 그대로 읽어, 테스트가 만든 노드들에 똑같이 연결한다.
## 테스트는 처리 함수(_on_*)를 직접 부르지 않고 원래 signal을 보내므로, 처리 함수 동작과 씬 연결이 함께 검증된다.
##
## 사용: var wired: int = SceneWiring.connect_like("res://scenes/main.tscn", {
##           "GameController/BoardChannel": board_channel, "SfxPlayer": sfx })
## nodes의 키는 씬 안의 노드 경로(루트 기준), 값은 테스트가 만든 인스턴스. 두 쪽이 모두 있는 연결만 이어 준다.


## 이어 준 연결 수를 반환한다.
## targets를 주면 그 노드들이 받는 연결만 잇는다 (signal을 보내는 쪽으로만 쓰는 대역 노드가
## 준비되지 않은 채 다른 이벤트를 받지 않게).
static func connect_like(scene_path: String, nodes: Dictionary, targets: PackedStringArray = PackedStringArray()) -> int:
	var state: SceneState = (load(scene_path) as PackedScene).get_state()
	var count: int = 0
	for i: int in state.get_connection_count():
		var source: String = String(state.get_connection_source(i))
		var target: String = String(state.get_connection_target(i))
		if not nodes.has(source) or not nodes.has(target):
			continue
		if not targets.is_empty() and not targets.has(target):
			continue
		var method: StringName = state.get_connection_method(i)
		var signal_name: StringName = state.get_connection_signal(i)
		var source_obj: Object = nodes[source]
		var target_obj: Object = nodes[target]
		if not source_obj.has_signal(signal_name) or not target_obj.has_method(method):
			push_error("SceneWiring: %s.%s → %s.%s does not exist on the test objects" % [source, signal_name, target, method])
			continue
		source_obj.connect(signal_name, Callable(target_obj, method))
		count += 1
	return count
