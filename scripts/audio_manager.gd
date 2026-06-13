extends Node
## 全局音效管理器 (autoload)
## 统一管理环境音效、UI音效、脚步声等
## 使用程序化生成的 WAV 文件，无需外部音频资源

# ============================================================================
# 配置
# ============================================================================
@export var master_volume: float = 1.0:
	set(v):
		master_volume = v
		_apply_volume()
@export var sfx_volume: float = 1.0:
	set(v):
		sfx_volume = v
		_apply_volume()
@export var footstep_interval: float = 0.45
@export var footstep_pitch_range: Vector2 = Vector2(0.85, 1.15)
@export var footstep_volume_db: float = -8.0

var _footstep_timer: float = 0.0
var _footstep_enabled: bool = false

var _sfx_players: Array[AudioStreamPlayer] = []
const MAX_SFX_PLAYERS := 8

var _footstep_streams: Array[AudioStream] = []
var _ui_click_stream: AudioStream


# ============================================================================
# 生命周期
# ============================================================================
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	for i in range(MAX_SFX_PLAYERS):
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer_" + str(i)
		player.bus = "Master"
		add_child(player)
		_sfx_players.append(player)

	_load_footstep_streams()


func _process(delta: float) -> void:
	if not _footstep_enabled:
		_footstep_timer = 0.0
		return

	_footstep_timer -= delta
	if _footstep_timer <= 0.0:
		_footstep_timer += footstep_interval
		_play_footstep()


# ============================================================================
# 音频流加载
# ============================================================================
func _load_footstep_streams() -> void:
	# 尝试加载 WAV 文件
	var paths := [
		"res://assets/audio/footstep_0.wav",
		"res://assets/audio/footstep_1.wav",
		"res://assets/audio/footstep_2.wav",
		"res://assets/audio/footstep_3.wav",
	]
	for p in paths:
		if FileAccess.file_exists(p):
			var stream := load(p) as AudioStream
			if stream:
				_footstep_streams.append(stream)

	if _footstep_streams.is_empty():
		push_warning("[AudioManager] 未找到脚步声 WAV 文件，已使用内置合成音效")
		_footstep_streams.append(_gen_synthetic_step())

	# UI 点击音
	var click_path := "res://assets/audio/ui_click.wav"
	if FileAccess.file_exists(click_path):
		_ui_click_stream = load(click_path) as AudioStream


func _gen_synthetic_step() -> AudioStream:
	# 使用 AudioStreamGenerator 生成一个短脉冲
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 44100
	gen.buffer_length = 0.08
	return gen


# ============================================================================
# 公有 API
# ============================================================================

func start_footsteps() -> void:
	_footstep_enabled = true
	_footstep_timer = 0.0


func stop_footsteps() -> void:
	_footstep_enabled = false
	_footstep_timer = 0.0


func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not stream:
		return
	var player := _find_free_player()
	if not player:
		return
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()


func play_ui_click() -> void:
	if _ui_click_stream:
		play_sfx(_ui_click_stream, -4.0)


func play_sfx_from_file(path: String, volume_db: float = 0.0) -> void:
	if not FileAccess.file_exists(path):
		push_warning("[AudioManager] 音效文件不存在: ", path)
		return
	var stream := load(path) as AudioStream
	if stream:
		play_sfx(stream, volume_db)


func play_footstep_random() -> void:
	if _footstep_streams.is_empty():
		return
	var stream := _footstep_streams[randi() % _footstep_streams.size()]
	var pitch := randf_range(footstep_pitch_range.x, footstep_pitch_range.y)
	play_sfx(stream, footstep_volume_db, pitch)


# ============================================================================
# 内部
# ============================================================================
func _play_footstep() -> void:
	play_footstep_random()


func _find_free_player() -> AudioStreamPlayer:
	for p in _sfx_players:
		if not p.playing:
			return p
	return _sfx_players[0]


func _apply_volume() -> void:
	var bus_idx := AudioServer.get_bus_index("Master")
	var db := linear_to_db(master_volume)
	AudioServer.set_bus_volume_db(bus_idx, db)
