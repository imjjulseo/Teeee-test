extends SceneTree
## QA 14: 프로세스를 다시 실행해도 최고 점수·캐릭터·조작 방법·마스터 볼륨이 유지된다.
## 전용 파일을 쓰므로 사용자 저장 파일은 건드리지 않는다.
## 1) godot --headless --path . -s tests/smoke/smoke_save_restart.gd -- write
## 2) godot --headless --path . -s tests/smoke/smoke_save_restart.gd -- read   (파일 확인 후 삭제)

const PATH: String = "user://smoke_restart_best.cfg"


func _initialize() -> void:
	var mode: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else ""
	var ok: bool = false
	if mode == "write":
		if FileAccess.file_exists(PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
		ok = BestScoreStore.new(PATH).submit(777)
		CharacterStore.new(PATH).select(&"joker")
		OptionsStore.new(PATH).set_control_mode(OptionsStore.ControlMode.DPAD)
		var options: OptionsStore = OptionsStore.new(PATH)
		options.set_master_volume(42)
		options.save_master_volume()
	elif mode == "read":
		var options: OptionsStore = OptionsStore.new(PATH)
		ok = BestScoreStore.new(PATH).best == 777 \
			and CharacterStore.new(PATH).selected_id == &"joker" \
			and options.control_mode == OptionsStore.ControlMode.DPAD \
			and options.master_volume == 42
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("SMOKE[smoke_save_restart %s] %s" % [mode, "PASS" if ok else "FAIL"])
	quit(0 if ok else 1)
