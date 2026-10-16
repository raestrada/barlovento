extends Control

const NEXT_SCENE_PATH := "res://scenes/sandbox/sandbox.tscn"
const VIDEO_PATH := "res://assets/video/intro.ogv"

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer
@onready var skip_prompt: Label = $HUD/SkipPrompt
@onready var fade_rect: ColorRect = $FadeRect
@onready var fallback_display: TextureRect = $FallbackDisplay

var _transitioning: bool = false
var _prompt_timer: float = 0.0

func _ready() -> void:
    fade_rect.modulate.a = 1.0
    skip_prompt.modulate.a = 0.0
    
    var stream = load(VIDEO_PATH)
    if stream:
        video_player.stream = stream
        video_player.finished.connect(_on_video_finished)
        video_player.play()
    else:
        fallback_display.visible = true
        _setup_fallback_timer()

    var tween := create_tween()
    tween.tween_property(fade_rect, "modulate:a", 0.0, 1.2)

func _process(delta: float) -> void:
    _prompt_timer += delta
    if _prompt_timer > 3.0 and not _transitioning:
        var alpha := (sin(_prompt_timer * 2.0) + 1.0) * 0.25 + 0.35
        skip_prompt.modulate.a = alpha

func _input(event: InputEvent) -> void:
    if _transitioning:
        return
    if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
        _proceed_to_game()
    elif event is InputEventMouseButton and event.pressed:
        _proceed_to_game()

func _on_video_finished() -> void:
    _proceed_to_game()

func _setup_fallback_timer() -> void:
    var timer := get_tree().create_timer(8.0)
    timer.timeout.connect(_proceed_to_game)

func _proceed_to_game() -> void:
    if _transitioning:
        return
    _transitioning = true
    
    var tween := create_tween()
    tween.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
    tween.tween_callback(_change_scene)

func _change_scene() -> void:
    get_tree().change_scene_to_file(NEXT_SCENE_PATH)
