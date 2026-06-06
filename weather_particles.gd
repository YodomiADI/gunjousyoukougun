# weather_particles.gd
# WeatherLayer (CanvasLayer) にアタッチする。
# GPUParticles2D を3種コードで生成し、set_weather() で切り替える。
#
# 使い方:
#   weather_layer.set_weather("heavy-rain")
#   weather_layer.set_weather("light-rain")
#   weather_layer.set_weather("snow")
#   weather_layer.set_weather("none")
extends CanvasLayer
 
# ============================================================
# 公開プロパティ
# ============================================================
@export_group("Initial State")
## 起動時の天気。空文字でOFF（none / heavy-rain / light-rain / snow）
@export_enum("continue", "none", "heavy-rain", "light-rain", "snow")  var initial_weather: String = ""
@export var viewport_width: float  = 1152.0
@export var viewport_height: float = 648.0
 
# ============================================================
# 内部定数・変数
# ============================================================
const FADE_DURATION_IN  = 3.0   # 降り始めにかける秒数
const FADE_DURATION_OUT = 2.5   # 止むのにかける秒数
 
var _particles: Dictionary = {}  # "heavy-rain" / "light-rain" / "snow" -> GPUParticles2D
var _current_weather: String = ""
var _fade_tween: Tween
 
 
func _ready() -> void:
	layer = 5
 
	# 3種のパーティクルを生成してシーンに追加
	_particles["heavy-rain"] = _create_heavy_rain()
	_particles["light-rain"] = _create_light_rain()
	_particles["snow"]       = _create_snow()
 
	for key in _particles:
		var p: GPUParticles2D = _particles[key]
		p.amount_ratio = 0.0
		p.emitting     = false
		add_child(p)
 
	# インスペクター設定の初期天気を即時適用（フェードなし）
	if initial_weather != "":
		_apply_instant(initial_weather)
		_current_weather = initial_weather
 
 
# ============================================================
# 公開 API
# ============================================================
 
## 天気を切り替える。現在と同じ天気を渡した場合は何もしない。
## "none" で停止。
func set_weather(new_weather: String) -> void:
	if new_weather == _current_weather:
		return
 
	_current_weather = new_weather
 
	# 進行中の Tween を破棄
	if _fade_tween:
		_fade_tween.kill()
		_fade_tween = null
 
	# --- フェードアウト対象を収集 ---
	var fade_out_targets: Array[GPUParticles2D] = []
	for key in _particles:
		var p: GPUParticles2D = _particles[key]
		if p.amount_ratio > 0.0:
			fade_out_targets.append(p)
 
	# --- フェードイン対象を確定 ---
	var fade_in_target: GPUParticles2D = null
	if new_weather != "none" and _particles.has(new_weather):
		fade_in_target = _particles[new_weather]
 
	# Tweenerが1本以上追加される場合のみ Tween を作る
	# （空の Tween を step() するとエラーになるため）
	var needs_tween = fade_out_targets.size() > 0 or fade_in_target != null
	if needs_tween:
		_fade_tween = create_tween().set_parallel(true)
 
		# フェードアウト
		for p in fade_out_targets:
			_fade_tween.tween_property(p, "amount_ratio", 0.0, FADE_DURATION_OUT) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
 
		# フェードイン（フェードアウトと同時スタート→小雨→本格雨がシームレス）
		if fade_in_target:
			fade_in_target.emitting = true
			_fade_tween.tween_property(fade_in_target, "amount_ratio", 1.0, FADE_DURATION_IN) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
 
	elif fade_in_target:
		# Tween 不要（フェードアウト対象ゼロ）だがフェードインは必要
		# → 直接 emitting をオンにして amount_ratio を手動アニメ
		fade_in_target.emitting = true
		_fade_tween = create_tween()
		_fade_tween.tween_property(fade_in_target, "amount_ratio", 1.0, FADE_DURATION_IN) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
 
	# FADE_DURATION_OUT 秒後に不要なパーティクルの emitting を止める
	get_tree().create_timer(FADE_DURATION_OUT + 0.5).timeout.connect(func():
		for key in _particles:
			if key != _current_weather:
				_particles[key].emitting = false
	)
 
 
## 現在の天気を返す
func get_weather() -> String:
	return _current_weather
 
 
# ============================================================
# インスタント適用（ロード時など、フェードなしで即反映）
# ============================================================
func _apply_instant(weather: String) -> void:
	for key in _particles:
		var p: GPUParticles2D = _particles[key]
		if key == weather:
			p.amount_ratio = 1.0
			p.emitting     = true
		else:
			p.amount_ratio = 0.0
			p.emitting     = false
 
 
# ============================================================
# ユーティリティ：雨粒テクスチャを ImageTexture で生成
# GPUParticles2D は Texture2D しか受け付けないため
# QuadMesh / SphereMesh は使えない。代わりに PNG ライクな
# ImageTexture をコードで作成して p.texture に渡す。
# ============================================================
 
## 縦長の雨粒テクスチャを生成する（幅 w px、高さ h px）
func _make_rain_texture(w: int, h: int, rain_color: Color) -> ImageTexture:
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	# 全ピクセルを塗る（グラデーションで上下を透明にして自然な雫に）
	for y in range(h):
		var t = float(y) / float(h - 1)               # 0.0 → 1.0
		# 上端・下端で透明、中央が最も濃い
		var alpha = sin(t * PI) * rain_color.a
		var c = Color(rain_color.r, rain_color.g, rain_color.b, alpha)
		for x in range(w):
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
 
 
## 丸い雪片テクスチャを生成する（直径 size px）
func _make_snow_texture(size: int, snow_color: Color) -> ImageTexture:
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size * 0.5, size * 0.5)
	var radius = size * 0.5
	for y in range(size):
		for x in range(size):
			var dist = Vector2(x, y).distance_to(center)
			# 円の内側はフェードイン、外側は透明
			var alpha = clampf(1.0 - (dist / radius), 0.0, 1.0)
			alpha = pow(alpha, 0.6)  # ふんわり感を出すためガンマ補正
			var c = Color(snow_color.r, snow_color.g, snow_color.b, alpha * snow_color.a)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
 
 
# ============================================================
# パーティクル生成：本格的な雨
# ============================================================
func _create_heavy_rain() -> GPUParticles2D:
	var p = GPUParticles2D.new()
	p.name     = "HeavyRain"
	p.amount   = 800
	p.lifetime = 0.6
	p.one_shot       = false
	p.explosiveness  = 0.0
	p.randomness     = 0.1
	p.fixed_fps      = 0
 
	# 表示領域を広げて、途中で雨が消えるのを防ぐ
	p.visibility_rect = Rect2(-viewport_width * 2, -viewport_height * 2, viewport_width * 4, viewport_height * 4)

	# --- テクスチャ：幅2px・高さ22pxの細長い雫 ---
	p.texture = _make_rain_texture(2, 22, Color(0.75, 0.88, 1.0, 1.0))
 
	var mat = ParticleProcessMaterial.new()
 
	# 放出形状：画面上部に広く帯状（左の余裕は斜め雨が画面左から侵入するため）
	mat.emission_shape      = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(viewport_width * 0.75, 1.0, 0.0)
 
	# 初速度：右斜め下に強く
	mat.direction            = Vector3(0.4, 1.0, 0.0)
	mat.spread               = 2.0
	mat.initial_velocity_min = 800.0
	mat.initial_velocity_max = 1050.0
 
	# 重力なし（初速で画面を一気に抜ける）
	mat.gravity = Vector3(0.0, 0.0, 0.0)
 
	# スケール：細い雫を表現
	mat.scale_min = 0.9
	mat.scale_max = 1.4
 
	# 色グラデーション（生成時・消滅時に透明にして自然に見せる）
	var grad = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.08, 0.9, 1.0])
	grad.colors = PackedColorArray([
		Color(0.75, 0.88, 1.0, 0.0),
		Color(0.75, 0.88, 1.0, 0.85),
		Color(0.70, 0.83, 1.0, 0.70),
		Color(0.70, 0.83, 1.0, 0.0)
	])
	var gtex = GradientTexture1D.new()
	gtex.gradient = grad
	mat.color_ramp = gtex
 
	p.process_material = mat
 
	# 放出位置：画面上辺より少し上
	p.position = Vector2(viewport_width * 0.5, -15.0)
 
	return p
 
 
# ============================================================
# パーティクル生成：小雨（しとしと）
# ============================================================
func _create_light_rain() -> GPUParticles2D:
	var p = GPUParticles2D.new()
	p.name     = "LightRain"
	p.amount   = 250
	#lifetime1.1だとメッセージウインドウ上ぐらいまでしか降らない
	p.lifetime = 2.5
	p.one_shot      = false
	p.explosiveness  = 0.0
	p.randomness     = 0.3
	p.fixed_fps      = 0
 
	# 表示領域を広げて、途中で雨が消えるのを防ぐ
	p.visibility_rect = Rect2(-viewport_width * 2, -viewport_height * 2, viewport_width * 4, viewport_height * 4)

	# テクスチャ：幅2px・高さ12pxの短い雫
	p.texture = _make_rain_texture(2, 12, Color(0.82, 0.92, 1.0, 1.0))
 
	var mat = ParticleProcessMaterial.new()
 
	mat.emission_shape       = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(viewport_width * 0.6, 1.0, 0.0)
 
	# ほぼ真下（わずかに斜め）
	mat.direction            = Vector3(0.05, 1.0, 0.0)
	mat.spread               = 5.0
	mat.initial_velocity_min = 280.0
	mat.initial_velocity_max = 380.0
 
	# わずかに重力（落下の加速感）
	mat.gravity = Vector3(0.0, 40.0, 0.0)
 
	mat.scale_min = 0.9
	mat.scale_max = 1.3
 
	var grad = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.15, 0.85, 1.0])
	grad.colors = PackedColorArray([
		Color(0.82, 0.92, 1.0, 0.0),
		Color(0.82, 0.92, 1.0, 0.60),
		Color(0.82, 0.92, 1.0, 0.50),
		Color(0.82, 0.92, 1.0, 0.0)
	])
	var gtex = GradientTexture1D.new()
	gtex.gradient = grad
	mat.color_ramp = gtex
 
	p.process_material = mat
	p.position = Vector2(viewport_width * 0.5, -15.0)
 
	return p
 
 
# ============================================================
# パーティクル生成：雪（ふわふわ、乱流で揺れる）
# ============================================================
func _create_snow() -> GPUParticles2D:
	var p = GPUParticles2D.new()
	p.name     = "Snow"
	p.amount   = 350
	p.lifetime = 6.0
	p.one_shot       = false
	p.explosiveness  = 0.0
	p.randomness     = 0.5
	p.fixed_fps      = 0

	# ★ 修正①：表示領域（visibility_rect）を画面の数倍に広げる！
	# これがないと、降っている途中で雪が空中で消滅してしまいます。
	p.visibility_rect = Rect2(-viewport_width * 2, -viewport_height * 2, viewport_width * 4, viewport_height * 4)

	# ★ 藍色（Indigo）の設定
	# R:0.2, G:0.3, B:0.6 あたりの深みのある青紫を採用しています
	var snow_color = Color(0.2, 0.35, 0.65, 1.0)
	
	# テクスチャ：20px のふんわり丸い雪片
	p.texture = _make_snow_texture(20, snow_color)

	var mat = ParticleProcessMaterial.new()

	mat.emission_shape       = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(viewport_width * 0.65, 1.0, 0.0)

	mat.direction            = Vector3(0.0, 1.0, 0.0)
	mat.spread               = 15.0
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 80.0

	# フワフワと落ちる適度な重力
	mat.gravity = Vector3(0.0, 15.0, 0.0)

	# ★ 修正②：暴走しやすい Turbulence をやめ、Tangential Accel で左右の揺らぎを作る
	mat.tangential_accel_min = -20.0
	mat.tangential_accel_max =  20.0
	mat.damping_min = 5.0
	mat.damping_max = 15.0

	# スケールにばらつき（遠近感）
	mat.scale_min = 0.6
	mat.scale_max = 1.4

	# 回転でひらひら感
	mat.angular_velocity_min = -30.0
	mat.angular_velocity_max =  30.0

	# 色グラデーション（藍色の透明度を操作。前回直した配列の書き方を採用）
	var grad = Gradient.new()
	grad.offsets = [0.0, 0.1, 0.85, 1.0]
	grad.colors = [
		Color(snow_color.r, snow_color.g, snow_color.b, 0.0),
		Color(snow_color.r, snow_color.g, snow_color.b, 0.88),
		Color(snow_color.r, snow_color.g, snow_color.b, 0.80),
		Color(snow_color.r, snow_color.g, snow_color.b, 0.0)
	]
	var gtex = GradientTexture1D.new()
	gtex.gradient = grad
	mat.color_ramp = gtex

	p.process_material = mat
	p.position = Vector2(viewport_width * 0.5, -20.0)

	return p
