class_name SceneNavigator
extends Node
## 씬 전환 노드. 대상 씬을 씬 파일에서 지정하고, 버튼 등의 signal을 go()에 연결해 사용한다.
## (씬끼리 PackedScene으로 서로 참조하면 순환 로드가 되므로 경로 문자열로 지정한다.)

@export_file("*.tscn") var target_scene: String


func go() -> void:
	var err: Error = get_tree().change_scene_to_file(target_scene)
	if err != OK:
		push_error("SceneNavigator: cannot change scene to %s (error %d)" % [target_scene, err])
