extends Node

const SFX_POOL_SIZE := 6
const BATTLE_MUSIC_PATH := "res://assets/audio/music_battle_march.ogg"
const MENU_MUSIC_PATH := "res://assets/audio/music_prologue.ogg"
const FALLBACK_MUSIC_PATH := "res://assets/audio/music/insistent.ogg"
const AMBIENT_PATH := "res://assets/audio/sfx/ambient_hum.ogg"

var _sfx: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0
var _music: AudioStreamPlayer
var _ambient: AudioStreamPlayer
var _current_music_path: String = ""

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
        "laser_heavy": "res://assets/audio/sfx/laser_naval_heavy.wav",
        "laser_pulse": "res://assets/audio/sfx/laser_lance_pulse.wav",
        "laser_cannon": "res://assets/audio/sfx/laser_broadside_cannon.wav",
        "explosion": "res://assets/audio/sfx/explosion.ogg",
        "explosion_big": "res://assets/audio/sfx/explosion_big.ogg",
        "shockwave": "res://assets/audio/sfx/explosion_cinematic_shockwave.wav",
        "impact": "res://assets/audio/sfx/impact.ogg",
        "ui_click": "res://assets/audio/sfx/ui_click.ogg",
        "ui_hover": "res://assets/audio/sfx/ui_hover.ogg",
        "engine": "res://assets/audio/sfx/engine_loop.ogg",
        "shield_hit": "res://assets/audio/sfx/shield_hit.ogg",
        "shield": "res://assets/audio/sfx/shield_hit.ogg",
    }
    for key in files:
        if ResourceLoader.exists(files[key]):
            _sfx[key] = load(files[key])

func play_sfx(sfx_name: String, volume_db: float = 0.0) -> void:
    if not _sfx.has(sfx_name):
        return
    var player := _sfx_players[_sfx_index]
    _sfx_index = (_sfx_index + 1) % SFX_POOL_SIZE
    player.stream = _sfx[sfx_name]
    player.volume_db = volume_db
    player.play()

func play_music(volume_db: float = -10.0) -> void:
    play_battle_music(volume_db)

func play_battle_music(volume_db: float = -10.0) -> void:
    var path := BATTLE_MUSIC_PATH if ResourceLoader.exists(BATTLE_MUSIC_PATH) else FALLBACK_MUSIC_PATH
    _start_music_track(path, volume_db)

func play_menu_music(volume_db: float = -11.0) -> void:
    var path := MENU_MUSIC_PATH if ResourceLoader.exists(MENU_MUSIC_PATH) else FALLBACK_MUSIC_PATH
    _start_music_track(path, volume_db)

func _start_music_track(path: String, volume_db: float) -> void:
    if _music == null:
        return
    if _music.playing and _current_music_path == path:
        _music.volume_db = volume_db
        return
    var stream := load(path)
    if stream is AudioStreamOggVorbis:
        stream.loop = true
    _current_music_path = path
    _music.stream = stream
    _music.volume_db = volume_db
    _music.play()

func start_ambient(volume_db: float = -26.0) -> void:
    if not ResourceLoader.exists(AMBIENT_PATH):
        return
    var stream: AudioStreamOggVorbis = load(AMBIENT_PATH)
    if stream != null:
        stream.loop = true
        _ambient.stream = stream
        _ambient.volume_db = volume_db
        _ambient.play()

func stop_music() -> void:
    if _music != null:
        _music.stop()
    _current_music_path = ""

