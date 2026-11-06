class_name AudioOptionsLoader
extends Node
## 씬이 열릴 때 저장된 오디오 옵션(마스터 볼륨)을 오디오 버스에 반영한다.
## 게임을 켜면 처음 여는 메인 메뉴와, 에디터에서 바로 실행할 수 있는 게임 씬에 둔다.
## (버스 볼륨은 씬을 바꿔도 유지되므로 한 번만 반영되면 충분하다.)

## 저장 파일. 비어 있으면 SaveData 기본 경로 (테스트·스모크는 SaveData.path_override).
@export var save_path: String = ""


func _ready() -> void:
	OptionsStore.new(save_path).apply_audio()
