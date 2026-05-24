# ripple_layer.gd
# CanvasLayer直下のColorRectにアタッチします。
extends ColorRect

# --- 定数（シェーダー側の MAX_RIPPLES / max_age と一致させる） ---
const MAX_RIPPLES = 10
const MAX_AGE     = 2.8

# --- エディタから調整可能なパラメータ ---
@export var min_move_pixels: float = 12.0  # マウスが何ピクセル動いたら波紋を出すか
@export var ripple_interval: float = 0.04  # 波紋生成の最小間隔（秒）
@export var is_active: bool = true          # 一時的に波紋を止めたいときはfalseにする

# --- 内部状態管理用 ---
var _positions: Array[Vector2] = []
var _ages: Array[float] = []
var _next_slot: int = 0
var _time_acc: float = 0.0
var _last_mouse: Vector2 = Vector2.ZERO
var _is_first_frame: bool = true           # マウス初期位置の誤爆（画面端からのワープ）防止用
var _dirty: bool = false                    # シェーダーの更新が必要かどうかのフラグ

func _ready() -> void:
	# 1. 重要：画面全体を覆うColorRectがゲームのクリック入力を邪魔しないように透過設定
	mouse_filter = MOUSE_FILTER_IGNORE
	
	# 2. 配列の初期化（Godot4のシェーダー配列に渡すため、通常の型指定Arrayを使用）
	_positions.resize(MAX_RIPPLES)
	_ages.resize(MAX_RIPPLES)
	for i in MAX_RIPPLES:
		_positions[i] = Vector2(0.5, 0.5)
		_ages[i] = 0.0

	# 3. 画面サイズへのフィッティングとリサイズ対策
	_resize_to_viewport()
	get_viewport().size_changed.connect(_resize_to_viewport)

	# 初期状態をシェーダーへ同期
	_sync_shader()

func _resize_to_viewport() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	size = vp_size

func _process(delta: float) -> void:
	# --- 1. すべての波紋の時間を進める ---
	for i in MAX_RIPPLES:
		if _ages[i] > 0.0:
			_ages[i] += delta
			if _ages[i] >= MAX_AGE:
				_ages[i] = 0.0
			_dirty = true

	# --- 2. マウスの動きを監視して波紋を生成 ---
	if is_active:
		var mouse = get_viewport().get_mouse_position()
		var vp_size = get_viewport().get_visible_rect().size
		_time_acc += delta

		if _is_first_frame:
			# 初回フレームはマウス位置を記憶するだけで、波紋生成はスキップ（ワープ暴走防止）
			_last_mouse = mouse
			_is_first_frame = false
		else:
			# 移動距離と経過時間の条件を満たした場合
			if mouse.distance_to(_last_mouse) >= min_move_pixels and _time_acc >= ripple_interval:
				# マウス座標をスクリーンUV（0.0 〜 1.0）に変換して追加
				var uv = mouse / vp_size
				_add_ripple(uv)
				_last_mouse = mouse
				_time_acc = 0.0

	# --- 3. 変更があった場合のみシェーダーにデータを送信（最適化） ---
	if _dirty:
		_sync_shader()
		_dirty = false

# --- 外部（クリックイベント等）から波紋を直接呼び出したい場合用の関数 ---
func add_ripple_at_screen_pos(screen_pos: Vector2) -> void:
	var vp_size = get_viewport().get_visible_rect().size
	_add_ripple(screen_pos / vp_size)

func _add_ripple(uv: Vector2) -> void:
	# リングバッファ方式で古いスロットを再利用
	_positions[_next_slot] = uv
	_ages[_next_slot] = 0.001 # 0.0より僅かに大きくすることで「アクティブ状態」にする
	_next_slot = (_next_slot + 1) % MAX_RIPPLES
	_dirty = true

func _sync_shader() -> void:
	if material == null:
		return
	
	# Godot 4 の仕様：型指定されたArrayをそのままインスペクターパラメータに転送
	material.set_shader_parameter("ripple_positions", _positions)
	material.set_shader_parameter("ripple_ages", _ages)
