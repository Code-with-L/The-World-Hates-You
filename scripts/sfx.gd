extends RefCounted

# Central sound-effect hooks for pass 4.
#
# The project ships no audio files, so every cue below resolves to null and every
# call is a single early return. Nothing here allocates a node, touches the scene
# tree, or runs per frame while there is nothing to play: with no audio present
# the whole subsystem costs one dictionary probe per call.
#
# To turn it on: drop matching files into AUDIO_DIR and call Sfx.attach(parent)
# once at startup (game_manager already does). The disasters need no changes.

const AUDIO_DIR := "res://assets/audio/"

# Cue name -> filename. Names are the contract the disasters use; the files are
# looked up lazily and cached.
const CUES := {
	"car_warning": "car_warning.ogg",
	"car_horn": "car_horn.ogg",
	"car_impact": "car_impact.ogg",
	"fall_warning": "fall_warning.ogg",
	"fall_impact": "fall_impact.ogg",
	"dog_bark": "dog_bark.ogg",
	"door_locked": "door_locked.ogg",
	"door_open": "door_open.ogg",
	"obstacle_land": "obstacle_land.ogg",
	"player_hurt": "player_hurt.ogg",
	"victory": "victory.ogg",
}

# Small fixed pool so overlapping cues reuse a voice instead of creating a node
# per hit. Eight is enough for the most the game can stack up at once.
const POOL := 8

static var _streams: Dictionary = {}
static var _players: Array[AudioStreamPlayer] = []
static var _next := 0
static var _searched := false


# Creates the voice pool under parent. Safe to call more than once.
static func attach(parent: Node) -> void:
	if not _players.is_empty() or parent == null or not is_instance_valid(parent):
		return
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		parent.add_child(p)
		_players.append(p)


static func play(cue: String, volume_db := 0.0, pitch := 1.0) -> void:
	var stream := _stream(cue)
	if stream == null:
		return
	if _players.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


static func has(cue: String) -> bool:
	return _stream(cue) != null


static func _stream(cue: String) -> AudioStream:
	if _streams.has(cue):
		return _streams[cue]
	if not _searched:
		_searched = true
		for key in CUES.keys():
			var path: String = AUDIO_DIR + String(CUES[key])
			if ResourceLoader.exists(path, "AudioStream"):
				var res := ResourceLoader.load(path, "AudioStream")
				if res is AudioStream:
					_streams[key] = res
	_streams[cue] = _streams.get(cue, null)
	return _streams[cue]
