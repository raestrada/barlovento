extends Node

const SFX_POOL_SIZE := 6
const MUSIC_PATH := "res://assets/audio/music/insistent.ogg"
const AMBIENT_PATH := "res://assets/audio/sfx/ambient_hum.ogg"

var _sfx: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0
var _music: AudioStreamPlayer
var _ambient: AudioStreamPlayer

func _ready() -> void:
    _load_sfx()

    for i in range(SFX_POOL_SIZE):
        var player := AudioStreamPlayer.new()
        add_child(player)
        _sfx_players.append(player)

    _music = AudioStreamPlayer.new()
    add_child(_music)

    _ambient = AudioStreamPlayer.new()
    add_child(_ambient)

func _load_sfx() -> void:
    var files := {
        "laser": "res://assets/audio/sfx/laser_shot.ogg",
        "laser_small": "res://assets/audio/sfx/laser_small.ogg",
        "explosion": "res://assets/audio/sfx/explosion.ogg",
        "explosion_big": "res://assets/audio/sfx/explosion_big.ogg",
        "impact": "res://assets/audio/sfx/impact.ogg",
        "ui_click": "res://assets/audio/sfx/ui_click.ogg",
        "ui_hover": "res://assets/audio/sfx/ui_hover.ogg",
        "engine": "res://assets/audio/sfx/engine_loop.ogg",
        "shield_hit": "res://assets/audio/sfx/shield_hit.ogg",
    }
    for key in files:
        _sfx[key] = load(files[key])

func play_sfx(sfx_name: String, volume_db: float = 0.0) -> void:
    if not _sfx.has(sfx_name):
        return
    var player := _sfx_players[_sfx_index]
    _sfx_index = (_sfx_index + 1) % SFX_POOL_SIZE
    player.stream = _sfx[sfx_name]
    player.volume_db = volume_db
    player.play()

func play_music(volume_db: float = -18.0) -> void:
    var stream: AudioStreamOggVorbis = load(MUSIC_PATH)
    stream.loop = true
    _music.stream = stream
    _music.volume_db = volume_db
    _music.play()

func start_ambient(volume_db: float = -30.0) -> void:
    var stream: AudioStreamOggVorbis = load(AMBIENT_PATH)
    stream.loop = true
    _ambient.stream = stream
    _ambient.volume_db = volume_db
    _ambient.play()

func stop_music() -> void:
    _music.stop()
