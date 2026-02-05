#timer_label.gd
extends Node2D

# --- 設定項目 ---
@export_group("Textures")
@export var tex_digits_white: Array[Texture2D] # 琥珀色
@export var tex_digits_red: Array[Texture2D]   # 赤色
@export var tex_colon_white: Texture2D
@export var tex_colon_red: Texture2D

@export_group("Physics")
const REPULSION_PEAK_DIST = 60.0 
const DIGIT_ESCAPE_POWER = 120.0  # 反発力を大幅に強化（逃げ足を速く）
const FATE_CHANGE_COUNT = 25  
const RELEASE_DIST = 150.0
# --- 状態管理 ---
var target_char_id = "Kokorone"
var is_captured = false    
var is_revealed = false    
var is_changing = false    
var is_hovering = false

var display_seconds: float = 0.0

# 各数字の「本来あるべき場所」を記憶する
var base_positions = {}

# HBoxContainerだと自動整列が動いてしまうため、
# 自由な移動をさせるなら Node2D または Control（整列なし）を推奨します
@onready var container = $Control
@onready var digits = [
	$Control/Year10, $Control/Year1,
	$Control/Month10, $Control/Month1,
	$Control/Day10, $Control/Day1,
	$Control/Hour10, $Control/Hour1,
	$Control/Min10, $Control/Min1,
	$Control/Sec10, $Control/Sec1
]

func _ready():
	# 初期化：不透明度固定、サイズを少し小さく設定（コードでやる場合）
	modulate.a = 1.0 
	container.scale = Vector2(0.4, 0.4) # 40%のサイズに
	
	for d in digits:
		base_positions[d] = d.position
	
	# 最初の更新
	update_display_by_state()

func _process(delta):
	# IDがない、もしくはデータがない場合は処理しない
	if target_char_id == "" or not Global.death_data.has(target_char_id):
		return
		
	# --- 追従解除のチェック ---
	if is_captured and not is_changing:
		var mouse_pos = get_local_mouse_position()
		# マウスとカウンターの中心(container.position)の距離を測る
		if mouse_pos.distance_to(container.position) > RELEASE_DIST:
			is_captured = false # 一定以上離れたら、ようやく解放する
	
	# 2. メインロジックの分岐
	if is_changing:
		perform_glitch_effect()
	elif is_captured:
		follow_mouse(delta)
		update_display_by_state()
	else:
		handle_repulsion()
		update_display_by_state()

# --- Glitch演出（毎フレーム実行） ---
func perform_glitch_effect():
	# グリッチ中は位置を激しく揺らすのみ
	container.position = Vector2(randf_range(-5, 5), randf_range(-5, 5))
	update_timer_images(randi(), true) # ランダム時はどちらかの色を使用
	
# --- 状態に応じた数字の更新（歪み vs 真実） ---
func update_display_by_state():
	var data = Global.death_data[target_char_id]
	if is_revealed:
		update_timer_images(int(data["white"]), false) # 琥珀色
	else:
		update_timer_images(int(data["red"]), true)   # 赤色

# --- マウスから逃げる（座標計算の修正） ---
func handle_repulsion():
	var mouse_pos = get_local_mouse_position() - container.position
	
	for d in digits:
		var origin = base_positions[d]
		var dist = mouse_pos.distance_to(d.position)
		
		# サイトの数式: (2 * N * d) / (d^2 + N^2)
		var repulsion = (2.0 * REPULSION_PEAK_DIST * dist) / (dist * dist + REPULSION_PEAK_DIST**2)
		var move_vec = (d.position - mouse_pos).normalized()
		var strength = repulsion * (DIGIT_ESCAPE_POWER / (dist + 1.0))
		
		# 「本来の位置」に戻ろうとしつつ、マウスから逃げる
		d.position = d.position.lerp(origin + move_vec * strength, 0.15)

# --- マウス追従（キャプチャ状態） ---
func follow_mouse(delta: float):
	var target_pos = get_local_mouse_position()
	# containerをゆっくりマウス位置へ
	container.position = container.position.lerp(target_pos, 10.0 * delta)
	
	# 数字の個別位置を元の位置（整列状態）にリセット
	for d in digits:
		d.position = d.position.lerp(base_positions[d], 0.2)

# --- 運命書き換え演出（トリガー） ---
func trigger_fate_change():
	is_changing = true
	is_captured = false # 書き換え中はマウス追従を解除
	
	# 指定回数分待機（この間 perform_glitch_effect が動く）
	for i in range(FATE_CHANGE_COUNT):
		await get_tree().create_timer(0.05).timeout
		
	# 演出終了
	is_changing = false
	is_revealed = true
	modulate = Color.WHITE 
	container.position = Vector2.ZERO # 位置をリセット

# --- 【重要】タイマー画像を実際にセットする関数 ---
# --- 【修正後】引数に use_red を追加しました ---
func update_timer_images(total_sec_val: int, use_red: bool):
	# エラー対策：引数名の total_sec_val を使う
	var s = abs(total_sec_val)
	
	# 時間分解ロジック
	var years = s / 31536000
	var rem_y = s % 31536000
	var months = rem_y / 2592000
	var rem_m = rem_y % 2592000
	var days = rem_m / 86400
	var rem_d = rem_m % 86400
	var hours = rem_d / 3600
	var rem_h = rem_d % 3600
	var minutes = rem_h / 60
	var seconds = rem_h % 60

	var vals = [
		years/10, years%10, months/10, months%10,
		days/10, days%10, hours/10, hours%10,
		minutes/10, minutes%10, seconds/10, seconds%10
	]
	
	# エラー対策：引数で受け取った use_red を使用する
	var current_set = tex_digits_red if use_red else tex_digits_white
	var current_colon = tex_colon_red if use_red else tex_colon_white
	
	# 数字更新
	for i in range(digits.size()):
		var n = int(vals[i]) % 10
		# 画像がセットされているか一応チェック（安全策）
		if n < current_set.size():
			digits[i].texture = current_set[n]
	
	# コロン更新
	for c in [$Control/Colon1, $Control/Colon2, $Control/Colon3, $Control/Colon4, $Control/Colon5]:
		if c: c.texture = current_colon
		
# --- 外部からのシグナル受信 ---
func _on_area_2d_mouse_entered():
	is_hovering = true
	is_captured = true 

func _on_area_2d_mouse_exited():
	is_hovering = false
	# ここで即座に is_captured = false にしないのがコツ！
	pass

# --- 入力イベント ---
func _input(event):
	if is_hovering and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# 【重要】このクリックイベントをここで「消費」して、
			# 他のスクリプト（main_gameなど）に伝わらないようにする！
			get_viewport().set_input_as_handled()

			if not is_revealed and not is_changing:
				trigger_fate_change()
