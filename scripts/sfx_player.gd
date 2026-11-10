class_name SfxPlayer
extends Node
## 효과음 재생 (기획서 7.2, B17). 실제 음원은 아직 없다.
## 게임 signal을 받아 효과음 ID로 바꾸고, sounds에 스트림이 지정된 ID만 재생한다.
## 음원을 넣을 때는 Inspector에서 sounds에 ID → AudioStream을 추가하기만 하면 된다.
## - 효과음 ID마다 전용 AudioStreamPlayer를 둔다 → 서로 다른 효과음이 같은 프레임에 나도 끊기지 않는다.
##   같은 효과음이 겹치면(빠른 이동음 등) 플레이어의 max_polyphony만큼 동시에 재생된다.
## - 모든 효과음은 bus(기본 "SFX")로 보낸다. 버스 구성: default_bus_layout.tres (Master ← SFX, BGM).
## - 플레이어 수는 sounds 데이터로 정해지므로 코드에서 만든다 (씬 규칙의 반복 노드 예외).

## 효과음 요청 (음원이 없어도 발생). 디버그/테스트용.
signal requested(id: StringName)

const MOVE: StringName = &"move"
const SWAP: StringName = &"swap"
const WALL: StringName = &"wall"
const MATCH: StringName = &"match"
const REFILL: StringName = &"refill"
const RECIPE_COMPLETE: StringName = &"recipe_complete"
const TICK: StringName = &"tick"
const TIME_UP: StringName = &"time_up"
const ABILITY: StringName = &"ability"
## 연쇄 폭파로 블록 하나가 터짐 (폭파범).
const BLAST: StringName = &"blast"

## 효과음 ID → 음원. 비어 있는 ID는 재생하지 않는다.
@export var sounds: Dictionary[StringName, AudioStream] = {}
## 효과음을 보낼 오디오 버스. 없으면 Master로 보낸다.
@export var bus: StringName = &"SFX"
## 같은 효과음이 동시에 겹쳐 재생될 수 있는 최대 수.
@export var polyphony_per_sound: int = 4

## 효과음 ID → 전용 플레이어 (처음 재생할 때 만든다).
var _players: Dictionary[StringName, AudioStreamPlayer] = {}


func play(id: StringName) -> void:
	requested.emit(id)
	var player: AudioStreamPlayer = get_player(id)
	if player == null or not player.is_inside_tree():
		return
	player.play()


## id의 효과음이 지금 재생 중인지.
func is_playing(id: StringName) -> bool:
	return _players.has(id) and _players[id].playing


## id 전용 플레이어. 음원이 없으면 null. 없으면 만든다 (sounds가 바뀌었으면 스트림을 맞춘다).
func get_player(id: StringName) -> AudioStreamPlayer:
	var stream: AudioStream = sounds.get(id)
	if stream == null:
		return null
	if not _players.has(id):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "Sfx_%s" % id
		player.bus = _resolve_bus()
		player.max_polyphony = maxi(polyphony_per_sound, 1)
		add_child(player)
		_players[id] = player
	var existing: AudioStreamPlayer = _players[id]
	if existing.stream != stream:
		existing.stream = stream
	return existing


func _resolve_bus() -> StringName:
	if AudioServer.get_bus_index(bus) >= 0:
		return bus
	push_warning("SfxPlayer: audio bus '%s' not found, using Master" % bus)
	return &"Master"


func _on_move_started(result: Board.MoveResult) -> void:
	play(MOVE if result.displaced_type == Board.CellType.EMPTY else SWAP)


func _on_move_blocked(_result: Board.MoveResult) -> void:
	play(WALL)


func _on_matched(_center: Vector2i, _color: int, _cells: Array[Vector2i]) -> void:
	play(MATCH)


func _on_cells_blasted(_cells: Array[Vector2i], _color: int) -> void:
	play(BLAST)


func _on_cells_refilled(_cells: Array[Vector2i]) -> void:
	play(REFILL)


func _on_recipes_updated(_recipes: RecipeSet, outcome: RecipeSet.ClearOutcome) -> void:
	if not outcome.completed_slots.is_empty():
		play(RECIPE_COMPLETE)


func _on_ability_triggered(_character: CharacterData, _message: String) -> void:
	play(ABILITY)


func _on_warning_tick() -> void:
	play(TICK)


func _on_time_up() -> void:
	play(TIME_UP)
