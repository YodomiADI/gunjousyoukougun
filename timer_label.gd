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
const DIGIT_ESCAPE_POWER = 180.0  # 反発力を大幅に強化（逃げ足を速く）
const FATE_CHANGE_COUNT = 25  
const RELEASE_DIST = 250.0
# --- 状態管理 ---
var target_char_id = "Kokorone"
var is_captured = false    
var is_revealed = false    
var is_changing = false    
var is_hovering = false

var display_seconds: float = 0.0
var last_displayed_seconds: int = -1

# 各数字の「本来あるべき場所」を記憶する
var base_positions = {}

# 現在の「見た目の中心（CanvasGroup基準）」を保持する変数
var current_visual_center: Vector2 = Vector2.ZERO

# HBoxContainerだと自動整列が動いてしまうため、
# 自由な移動をさせるなら Node2D または Control（整列なし）を推奨します
@onready var container = $CanvasGroup # シェーダーがかかっているのはココ！
@onready var digits = [
	$CanvasGroup/Year10, $CanvasGroup/Year1,
	$CanvasGroup/Month10, $CanvasGroup/Month1,
	$CanvasGroup/Day10, $CanvasGroup/Day1,
	$CanvasGroup/Hour10, $CanvasGroup/Hour1,
	$CanvasGroup/Min10, $CanvasGroup/Min1,
	$CanvasGroup/Sec10, $CanvasGroup/Sec1
]

func update_collision_size():
	# 1. 全てのスプライトを包む矩形（Rect2）を作成
	var total_rect = Rect2()
	var sprites = $CanvasGroup.get_children()
	
	if sprites.size() > 0:
	# 最初のスプライトで初期化
		total_rect = sprites[0].get_rect()
		total_rect.position += sprites[0].position
		
		# 全ての数字スプライトを合算
		for i in range(1, sprites.size()):
			var sprite = sprites[i]
			var sprite_rect = sprite.get_rect()
			sprite_rect.position += sprite.position
			total_rect = total_rect.merge(sprite_rect)

	# 2. CollisionShape2D のサイズを更新
	# ※前回の指摘通り、TimerCollision自体のScaleは(1,1)にしておき、
	#   内部の shape.size (RectangleShape2D) を変更します。
	if $CanvasGroup/TimerArea/TimerCollision.shape is RectangleShape2D:
		$CanvasGroup/TimerArea/TimerCollision.shape.size = total_rect.size
		# 中心位置の調整（スプライトの並びが中心基準でない場合）
		$CanvasGroup/TimerArea/TimerCollision.position = total_rect.get_center()


# 当たり判定を自動生成する関数
func setup_collision_shape():
	if digits.is_empty(): return
	
	# 1. 全ての数字を包む最小の四角形(Rect2)を計算する
	var total_rect = Rect2()
	var first = true
	
	for d in digits:
		if d is Sprite2D and d.texture:
			# スプライトの「現在のスケール」を考慮したサイズを取得
			var s_size = d.texture.get_size() * d.scale
			# スプライトの中心点(Offset)を考慮したローカルの矩形
			var rect = Rect2(d.position - s_size / 2.0, s_size)
			
			if first:
				total_rect = rect
				first = false
			else:
				total_rect = total_rect.merge(rect)

	# 2. マージン（遊び）を追加
	var margin = Vector2(80.0, 40.0) # お好みで調整
	var final_size = total_rect.size + margin
	
	# 3. CollisionShape2D に適用
	# ※パスはご自身のシーンツリーに合わせて $CanvasGroup/TimerArea/... などに直してください
	var collision_node = $CanvasGroup/TimerArea/TimerCollision
	if collision_node and collision_node.shape is RectangleShape2D:
		collision_node.shape.size = final_size
		# 四角形の中心に当たり判定を移動
		collision_node.position = total_rect.get_center()
		
	# --- 重要：プロキシ（影武者）側にもこのサイズを伝える ---
	sync_to_proxy(final_size, total_rect.get_center())

# プロキシの形を更新するための関数を追加
func sync_to_proxy(new_size: Vector2, new_center: Vector2):
	# character_display.gd を経由して、外側の TimerProxy のサイズも変える
	var parent_display = get_parent()
	if parent_display and "timer_proxy" in parent_display:
		var proxy = parent_display.timer_proxy
		if proxy:
			var p_col = proxy.get_node_or_null("CollisionShape2D")
			if p_col and p_col.shape is RectangleShape2D:
				# プロキシの当たり判定サイズも実体と同期させる
				p_col.shape.size = new_size * container.scale # containerのスケールも考慮
				p_col.position = new_center * container.scale

# シェーダー制御用のTween
var tween_shader: Tween

func _ready():
	# 初期化：不透明度固定、サイズを少し小さく設定（コードでやる場合）
	modulate.a = 1.0 
	container.scale = Vector2(0.4, 0.4) # 40%のサイズに
	
	# 念のため、1フレーム待ってから計算するとテクスチャの読み込み漏れを防げます
	await get_tree().process_frame 
	setup_collision_shape()
	
	for d in digits:
		base_positions[d] = d.position
	
	# 最初の更新
	update_display_by_state()

func _process(delta):
	# IDがない、もしくはデータがない場合は処理しない
	if target_char_id == "" or not Global.death_data.has(target_char_id):
		return
		
	# --- 1.追従解除のチェック ---
	if is_captured and not is_changing:
		# ★修正: 判定の中心からの距離を測るように変更
		var global_mouse = get_global_mouse_position()
		var visual_global_pos = to_global(container.position + current_visual_center)
		
		if global_mouse.distance_to(visual_global_pos) > RELEASE_DIST:
			is_captured = false
			stop_glow_effect()
			
	# --- 2. 物理・動きの処理（これは毎フレーム滑らかに動かす！） ---
	if is_changing:
		perform_glitch_effect()
	elif is_captured:
		follow_mouse(delta)
	else:
		handle_repulsion()
	# --- ★重要追加: 動いた結果に合わせて、当たり判定の場所とサイズを更新する ---
	update_collision_runtime()

	# --- 3. 見た目（テクスチャ更新）の処理 ---
	var current_sec_int = int(Global.get_current_death_time(target_char_id))
	if current_sec_int != last_displayed_seconds:
		update_display_by_state()
		last_displayed_seconds = current_sec_int
		
# --- ★新設: 毎フレーム当たり判定を計算し直す関数 ---
func update_collision_runtime():
	if digits.is_empty(): return
	
	# 1. 散らばった数字たちを包む「矩形（Rect2）」を計算
	var total_rect = Rect2()
	var first = true
	
	for d in digits:
		# 数字の現在位置（CanvasGroup内でのローカル座標）
		var d_pos = d.position
		# テクスチャサイズ（スケール考慮）
		var d_size = Vector2(40, 60) # デフォルト値（テクスチャロード前対策）
		if d.texture:
			d_size = d.texture.get_size() * d.scale
		
		var rect = Rect2(d_pos - d_size / 2.0, d_size)
		
		if first:
			total_rect = rect
			first = false
		else:
			total_rect = total_rect.merge(rect)
	
	# 2. マージン（余白）を足す
	var margin = Vector2(40.0, 40.0) # 逃げやすくするため少し大きめに
	total_rect = total_rect.grow_individual(margin.x, margin.y, margin.x, margin.y)
	
	# 3. CanvasGroup内のローカル当たり判定を更新
	var col_shape = $CanvasGroup/TimerArea/TimerCollision
	if col_shape and col_shape.shape is RectangleShape2D:
		col_shape.shape.size = total_rect.size
		col_shape.position = total_rect.get_center()

	# 4. 「見た目の中心」を記録（これをcharacter_display.gdで使う）
	current_visual_center = total_rect.get_center()
	
	# シェーダーやCanvasGroup自体が動いている場合、その親からの相対座標に変換
	# CharacterDisplayが欲しいのは「TimerLabelノードの(0,0)から、今の見た目はどこにあるか」
	# = CanvasGroupのズレ + CanvasGroup内の数字のズレ
	
# --- ★新設: 外部から呼ぶための座標取得関数 ---
func get_current_visual_offset() -> Vector2:
	# CanvasGroupの位置(container.position) + 散らばった数字の中心(current_visual_center)
	return container.position + current_visual_center
	
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
	container.position = container.position.lerp(target_pos, 25.0 * delta)
	
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
	
	# 状態が変わったので、次の1秒を待たずに今すぐ見た目を更新する
	update_display_by_state()
	
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
	for c in [$CanvasGroup/Colon1, $CanvasGroup/Colon2, $CanvasGroup/Colon3, $CanvasGroup/Colon4, $CanvasGroup/Colon5]:
		if c: c.texture = current_colon
		
# --- 外部からのシグナル受信 ---
func _on_area_2d_mouse_entered():
	is_hovering = true
	is_captured = true 
	start_glow_effect() # ★追加：光らせる
	print("マウスが入った！")
func _on_area_2d_mouse_exited():
	is_hovering = false
	print("マウスがでた！")
	# ここで即座に is_captured = false にしないのがコツ！
	pass

# --- 入力イベント ---
# 外部からクリックを通知するための関数
func handle_proxy_click():
	if not is_revealed and not is_changing:
		trigger_fate_change()

# 元の _input は、念のため残すか、プロキシ専用にするなら消してもOK
func _input(event):
	# SubViewport内の直接クリックも有効にしたい場合のみ残す
	if is_hovering and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			get_viewport().set_input_as_handled()
			handle_proxy_click() # 共通の処理を呼ぶ
			
# --- 追加：波紋演出の関数 ---
# 吸い付き開始時の処理（_on_area_2d_mouse_entered内などから呼ぶ）
# マウスが触れた時の演出開始
func start_glow_effect():
	for d in digits:
		# 各数字からマテリアルを取得
		var mat = d.material as ShaderMaterial
		if not mat: continue # マテリアルが設定されていない場合はスルー
		
		# Tweenで個別にアニメーション（並列処理）
		var tween = create_tween().set_parallel(true)
		# 強度を上げる（泡をくっきりさせる）
		tween.tween_property(mat, "shader_parameter/effect_strength", 0.8, 0.4).set_trans(Tween.TRANS_CUBIC)
		# 泡のスピードを少し速くして「反応してる感」を出す
		tween.tween_property(mat, "shader_parameter/speed", 0.6, 0.4)
		tween.tween_property(d, "modulate", Color(0.8, 0.9, 1.0), 0.4) # 少し青白くする
# 吸い付き終了時の処理
func stop_glow_effect():
	for d in digits:
		var mat = d.material as ShaderMaterial
		if not mat: continue
		
		var tween = create_tween().set_parallel(true)
		# 強度を0に戻して泡を消す
		tween.tween_property(mat, "shader_parameter/effect_strength", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
		# スピードも元に戻す
		tween.tween_property(mat, "shader_parameter/speed", 0.2, 0.6)
