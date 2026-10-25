extends Node

const SFX_POOL_SIZE := 6

const MENU_MUSIC_PATH := "res://assets/audio/music_prologue.ogg"
const BATTLE_ACERO_PATH := "res://assets/audio/music_battle_march.ogg"
const BATTLE_VINCULADOS_PATH := "res://assets/audio/music/music_vinculados.ogg"
const BATTLE_MAREA_PATH := "res://assets/audio/music/music_marea.ogg"
const BATTLE_ACE_PATH := "res://assets/audio/music/music_ace_tactical.ogg"
const BATTLE_CLIMAX_PATH := "res://assets/audio/music/music_climax.ogg"
const VICTORY_FANFARE_PATH := "res://assets/audio/music/music_victory.wav"
const DEFEAT_CUE_PATH := "res://assets/audio/music/music_defeat.wav"
const FALLBACK_MUSIC_PATH := "res://assets/audio/music/insistent.ogg"
const AMBIENT_PATH := "res://assets/audio/sfx/ambient_hum.ogg"

const BATTLE_PLAYLIST: Array[String] = [
	BATTLE_ACERO_PATH,
	BATTLE_MAREA_PATH,
	BATTLE_VINCULADOS_PATH,
	BATTLE_ACE_PATH,
	BATTLE_CLIMAX_PATH,
]

const TRACK_TITLES: Dictionary = {
	"res://assets/audio/music_prologue.ogg": "Gustav Holst — Venus, Bringer of Peace (Prologue Master)",
	"res://assets/audio/music_battle_march.ogg": "Gustav Holst — Mars, Bringer of War (Armada of Acero)",
	"res://assets/audio/music/music_marea.ogg": "Gustav Holst — Jupiter, Bringer of Jollity (The Free Tide)",
	"res://assets/audio/music/music_vinculados.ogg": "Gustav Holst — Uranus, the Magician (The Vinculados)",
	"res://assets/audio/music/music_ace_tactical.ogg": "Gustav Holst — Mercury, Winged Messenger (Ace Dogfight)",
	"res://assets/audio/music/music_climax.ogg": "Antonín Dvořák — Symphony No. 9 'New World' Allegro con fuoco",
	"res://assets/audio/music/out_there.ogg": "Deep Space Overture — Out There (Atmospheric Star Sea)",
	"res://assets/audio/music/insistent.ogg": "Dramatic Overture — Insistent March",
	"res://assets/audio/music/music_victory.wav": "Symphonic Fanfare — Mission Accomplished",
	"res://assets/audio/music/music_defeat.wav": "Symphonic Elegy — Flagship Down",
}

var master_volume: float = 1.0
var music_volume: float = 0.85
var sfx_volume: float = 1.0
var ambient_volume: float = 0.80

var _base_music_db: float = -11.0
var _base_ambient_db: float = -24.0

var _sfx: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0
var _music: AudioStreamPlayer
var _ambient: AudioStreamPlayer
var _current_music_path: String = ""
var _fade_tween: Tween
var _current_playlist_idx: int = 0

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

func set_master_volume(linear: float) -> void:
	master_volume = clampf(linear, 0.0, 1.0)
	_apply_volumes()

func set_music_volume(linear: float) -> void:
	music_volume = clampf(linear, 0.0, 1.0)
	_apply_volumes()

func set_sfx_volume(linear: float) -> void:
	sfx_volume = clampf(linear, 0.0, 1.0)

func set_ambient_volume(linear: float) -> void:
	ambient_volume = clampf(linear, 0.0, 1.0)
	_apply_volumes()

func _apply_volumes() -> void:
	if _music != null and _music.playing:
		var effective_music := clampf(master_volume * music_volume, 0.0001, 1.0)
		_music.volume_db = _base_music_db + linear_to_db(effective_music)
	if _ambient != null and _ambient.playing:
		var effective_ambient := clampf(master_volume * ambient_volume, 0.0001, 1.0)
		_ambient.volume_db = _base_ambient_db + linear_to_db(effective_ambient)

func play_sfx(sfx_name: String, volume_db: float = 0.0) -> void:
	if not _sfx.has(sfx_name):
		return
	var player := _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % SFX_POOL_SIZE
	player.stream = _sfx[sfx_name]
	var effective_sfx := clampf(master_volume * sfx_volume, 0.0001, 1.0)
	player.volume_db = volume_db + linear_to_db(effective_sfx)
	player.play()

func play_music(volume_db: float = -10.0) -> void:
	play_battle_music(volume_db)

func play_battle_music(volume_db: float = -10.0, faction: String = "", stage_id: String = "") -> void:
	var target_path := _resolve_battle_track(faction, stage_id)
	crossfade_to(target_path, volume_db, 1.0)

func play_ace_tactical_music(volume_db: float = -10.0) -> void:
	var path := BATTLE_ACE_PATH if ResourceLoader.exists(BATTLE_ACE_PATH) else BATTLE_ACERO_PATH
	crossfade_to(path, volume_db, 0.8)

func play_menu_music(volume_db: float = -11.0) -> void:
	var path := MENU_MUSIC_PATH if ResourceLoader.exists(MENU_MUSIC_PATH) else FALLBACK_MUSIC_PATH
	crossfade_to(path, volume_db, 1.0)

func play_victory_fanfare(volume_db: float = -5.0) -> void:
	var path := VICTORY_FANFARE_PATH if ResourceLoader.exists(VICTORY_FANFARE_PATH) else BATTLE_MAREA_PATH
	_play_one_shot_music(path, volume_db)

func play_defeat_cue(volume_db: float = -5.0) -> void:
	var path := DEFEAT_CUE_PATH if ResourceLoader.exists(DEFEAT_CUE_PATH) else BATTLE_ACERO_PATH
	_play_one_shot_music(path, volume_db)

func next_battle_track(volume_db: float = -10.0) -> String:
	_current_playlist_idx = (_current_playlist_idx + 1) % BATTLE_PLAYLIST.size()
	var path: String = BATTLE_PLAYLIST[_current_playlist_idx]
	if not ResourceLoader.exists(path):
		path = BATTLE_ACERO_PATH
	crossfade_to(path, volume_db, 0.6)
	return get_current_track_title()

func get_current_track_title() -> String:
	return TRACK_TITLES.get(_current_music_path, "Unknown Symphonic Movement")

func _resolve_battle_track(faction: String, stage_id: String) -> String:
	# Climax stages (e.g. stage 11, stage 12 or calm threshold) get the epic Dvorak New World Allegro
	var s_lower := stage_id.to_lower()
	if "11" in s_lower or "12" in s_lower or "climax" in s_lower or "calm" in s_lower or "dam" in s_lower or "ascension" in s_lower:
		if ResourceLoader.exists(BATTLE_CLIMAX_PATH):
			return BATTLE_CLIMAX_PATH

	var f_lower := faction.to_lower()
	if "marea" in f_lower:
		if ResourceLoader.exists(BATTLE_MAREA_PATH):
			return BATTLE_MAREA_PATH
	elif "vinculados" in f_lower:
		if ResourceLoader.exists(BATTLE_VINCULADOS_PATH):
			return BATTLE_VINCULADOS_PATH

	if ResourceLoader.exists(BATTLE_ACERO_PATH):
		return BATTLE_ACERO_PATH
	return FALLBACK_MUSIC_PATH

func crossfade_to(path: String, target_volume_db: float = -10.0, fade_duration: float = 0.8) -> void:
	if _music == null:
		return
	if not ResourceLoader.exists(path):
		path = FALLBACK_MUSIC_PATH
		if not ResourceLoader.exists(path):
			return

	if _music.playing and _current_music_path == path:
		# Just smoothly interpolate volume if needed
		if _fade_tween != null and _fade_tween.is_valid():
			_fade_tween.kill()
		_fade_tween = create_tween()
		_fade_tween.tween_property(_music, "volume_db", target_volume_db, 0.4)
		return

	if not _music.playing:
		_start_music_track(path, target_volume_db)
		return

	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()

	_fade_tween = create_tween()
	var half_dur := maxf(0.2, fade_duration * 0.45)
	_fade_tween.tween_property(_music, "volume_db", -40.0, half_dur)
	_fade_tween.tween_callback(func() -> void:
		_start_music_track(path, -40.0)
	)
	_fade_tween.tween_property(_music, "volume_db", target_volume_db, half_dur)

func _start_music_track(path: String, volume_db: float) -> void:
	if _music == null:
		return
	var stream = load(path)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	_current_music_path = path
	_music.stream = stream
	_base_music_db = volume_db
	var effective_music := clampf(master_volume * music_volume, 0.0001, 1.0)
	_music.volume_db = volume_db + linear_to_db(effective_music)
	_music.play()

func _play_one_shot_music(path: String, volume_db: float) -> void:
	if _music == null:
		return
	if not ResourceLoader.exists(path):
		return
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	var stream = load(path)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = false
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	_current_music_path = path
	_music.stream = stream
	_base_music_db = volume_db
	var effective_music := clampf(master_volume * music_volume, 0.0001, 1.0)
	_music.volume_db = volume_db + linear_to_db(effective_music)
	_music.play()

func start_ambient(volume_db: float = -26.0) -> void:
	if not ResourceLoader.exists(AMBIENT_PATH):
		return
	var stream = load(AMBIENT_PATH)
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	if stream != null:
		_ambient.stream = stream
		_base_ambient_db = volume_db
		var effective_ambient := clampf(master_volume * ambient_volume, 0.0001, 1.0)
		_ambient.volume_db = volume_db + linear_to_db(effective_ambient)
		_ambient.play()

func stop_music() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if _music != null:
		_music.stop()
	_current_music_path = ""
