extends "res://tests/framework/test_case.gd"
## 오디오 버스(default_bus_layout.tres)와 효과음 ID별 플레이어. 실제 동시 재생은 스모크(smoke_feedback)에서 확인한다.


## 짧은 테스트 음(16bit 모노 사인파).
func _tone(hz: float, seconds: float = 0.4) -> AudioStreamWAV:
	var rate: int = 22050
	var data: PackedByteArray = PackedByteArray()
	data.resize(int(rate * seconds) * 2)
	for i: int in int(rate * seconds):
		data.encode_s16(i * 2, int(sin(TAU * hz * i / rate) * 12000.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream


func _sfx() -> SfxPlayer:
	return (load("res://scenes/sfx_player.tscn") as PackedScene).instantiate() as SfxPlayer


func test_bus_layout_has_sfx_and_bgm_into_master() -> void:
	for bus_name: StringName in [&"SFX", &"BGM"]:
		var index: int = AudioServer.get_bus_index(bus_name)
		assert_true(index > 0, "%s bus exists" % bus_name)
		if index > 0:
			assert_eq(AudioServer.get_bus_send(index), &"Master", "%s sends to Master" % bus_name)


func test_each_sound_gets_its_own_player_on_sfx_bus() -> void:
	var sfx: SfxPlayer = _sfx()
	sfx.sounds = {SfxPlayer.MATCH: _tone(660.0), SfxPlayer.RECIPE_COMPLETE: _tone(880.0)}
	var match_player: AudioStreamPlayer = sfx.get_player(SfxPlayer.MATCH)
	var recipe_player: AudioStreamPlayer = sfx.get_player(SfxPlayer.RECIPE_COMPLETE)
	assert_true(match_player != null and recipe_player != null)
	assert_true(match_player != recipe_player, "different sounds never share (and cut) a player")
	assert_eq(sfx.get_player(SfxPlayer.MATCH), match_player, "same sound reuses its player")
	for player: AudioStreamPlayer in [match_player, recipe_player]:
		assert_eq(player.bus, &"SFX")
		assert_eq(player.max_polyphony, sfx.polyphony_per_sound, "same sound can overlap")
	assert_eq(match_player.stream, sfx.sounds[SfxPlayer.MATCH])
	sfx.free()


func test_sound_without_stream_has_no_player() -> void:
	var sfx: SfxPlayer = _sfx()
	assert_eq(sfx.get_player(SfxPlayer.MOVE), null)
	sfx.play(SfxPlayer.MOVE)  # 음원 없음 → 조용히 넘어감
	assert_false(sfx.is_playing(SfxPlayer.MOVE))
	sfx.free()


func test_replacing_a_sound_updates_its_player() -> void:
	var sfx: SfxPlayer = _sfx()
	sfx.sounds = {SfxPlayer.WALL: _tone(200.0)}
	var player: AudioStreamPlayer = sfx.get_player(SfxPlayer.WALL)
	var replacement: AudioStreamWAV = _tone(150.0)
	sfx.sounds[SfxPlayer.WALL] = replacement
	assert_eq(sfx.get_player(SfxPlayer.WALL), player)
	assert_eq(player.stream, replacement)
	sfx.free()


func test_missing_bus_falls_back_to_master() -> void:
	var sfx: SfxPlayer = _sfx()
	sfx.bus = &"NoSuchBus"
	sfx.sounds = {SfxPlayer.TICK: _tone(440.0)}
	assert_eq(sfx.get_player(SfxPlayer.TICK).bus, &"Master")
	sfx.free()
