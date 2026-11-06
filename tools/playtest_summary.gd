extends SceneTree
## 플레이 기록 요약 (기획서 10.1장):
##   godot --headless --path . -s tools/playtest_summary.gd             (기본: user://playtest_log.csv)
##   godot --headless --path . -s tools/playtest_summary.gd -- <경로>   (다른 CSV, 예: 팀원이 보낸 기록)


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var path: String = args[0] if not args.is_empty() else PlaytestLog.DEFAULT_PATH
	if not FileAccess.file_exists(path):
		printerr("playtest_summary: no log at %s (%s)" % [path, ProjectSettings.globalize_path(path)])
		quit(1)
		return
	print("playtest_summary: %s" % ProjectSettings.globalize_path(path))
	for line: String in PlaytestSummary.from_csv(FileAccess.get_file_as_string(path)).lines():
		print(line)
	quit(0)
