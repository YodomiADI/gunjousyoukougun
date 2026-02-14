# character_display.gd の1行目に追加
class_name CharacterDisplay
# character_display.gd
extends Node2D

# --- エディタのインスペクターから、スロットごとの基本倍率を設定できるようにする ---
@export var base_scale: float = 1.0

@onready var sprite = $Sprite2D # 名前に注意！Sprite2D か Sprite か
@onready var timer_label = $TimerLabel

# 【キャラ用】マウスが乗ったことを検知してタイマーを出すための判定
@onready var char_area = $CharacterArea
@onready var char_collision = $CharacterArea/CharacterCollision

# 外側の判定ノード（影武者）をインスペクターで指定できるようにする
@export var char_proxy: Area2D
@export var timer_proxy: Area2D

# ※ TimerArea（タイマーが逃げる用）は、timer_label.gd側で処理するため
#   このスクリプトからは触らないようにして、混線を防ぎます。

var current_character_name: String = ""
var current_char_id: int = 0


# ループが重複しないためのガード
var is_dripping = false
var current_timer_offset_y: float = 0.0  

func _ready():
	timer_label.hide() # 最初は隠しておく
	if timer_proxy:
		# プロキシの入力イベント（クリックなど）を監視する
		timer_proxy.input_event.connect(_on_timer_proxy_input_event)
		# timer_labelを直接呼ぶのではなく、このスクリプトの下の方にある
		# 「フラグ管理付きの関数」を呼ぶように変更します。
		timer_proxy.mouse_entered.connect(_on_timer_proxy_mouse_entered)
		timer_proxy.mouse_exited.connect(_on_timer_proxy_mouse_exited)
		
# main_game.gd から呼ばれる関数名
func display(display_name: String, texture: Texture2D, char_id: int = 0, offset_y: float = -40.0, char_scale: float = 1.0, b_scale: float = 1.0):
	current_character_name = display_name
	current_char_id = char_id
	current_timer_offset_y = offset_y
	
	# 素材本来の大きさ(b_scale) と 演出用の大きさ(char_scale) を掛け合わせる
	var final_scale = b_scale * char_scale
	
	if is_visible_in_tree():
		var scale_tween = create_tween()
		scale_tween.tween_property(self, "scale", Vector2(final_scale, final_scale), 0.2).set_trans(Tween.TRANS_SINE)
	else:
		self.scale = Vector2(final_scale, final_scale)
	
	# --- 修正箇所開始：先に内部の当たり判定を確定させる ---
	
	if texture:
		sprite.texture = texture
		var tex_size = texture.get_size()
		
		# 2. 当たり判定（CollisionShape2D）を画像サイズに合わせる
		if char_collision.shape == null:
			char_collision.shape = RectangleShape2D.new()
			
		# --- 判定を上に伸ばし、中心を調整する ---
		var extra_height = 100.0 
		var new_size = Vector2(tex_size.x, tex_size.y + extra_height)
		char_collision.shape.size = new_size
		
		# 中心位置を「半分だけ上」にずらす
		char_collision.position.y = -extra_height / 2.0
		
		# 死期ラベルの位置調整
		timer_label.position.y = -(tex_size.y / 2.0) + offset_y

		# ==========================================================
		# ★修正：ここから「影武者（Proxy）」に内部判定をコピーする処理
		# ==========================================================
		if char_proxy:
			var p_col = char_proxy.get_node("CollisionShape2D")
			if p_col:
				# 重要：リソース共有を切るため、Shapeが共有されていたら複製してユニークにする
				if p_col.shape == null:
					p_col.shape = RectangleShape2D.new()
				else:
					# すでに割り当たっている場合、他のスロットと共有している可能性が高いため複製する
					# (これをしないとLeftを変えた時にRightも変わってしまう)
					p_col.shape = p_col.shape.duplicate()

				# 内部で作った「new_size」にスケールを適用してプロキシに渡す
				# ※char_proxy自体はscale=1.0のままなので、ここで倍率を掛ける必要があります
				p_col.shape.size = char_collision.shape.size * final_scale
				
				# 重要：位置（ズレ）もコピーする
				# char_collisionは上にズレているので、プロキシも同じ比率でズラす
				p_col.position = char_collision.position * final_scale
		# ==========================================================
		# ==========================================================
		if timer_proxy:
			# 1. 位置の同期
			# TimerLabel はキャラの頭上に移動しているので、その位置をスケール倍して適用
			timer_proxy.position = timer_label.position * final_scale
			
			# 2. サイズの同期（当たり判定のリソース重複回避も含む）
			# TimerLabelの中にある本来の判定を取得
			var t_col_node = timer_label.get_node_or_null("CanvasGroup/TimerArea/TimerCollision")
			var p_col_node = timer_proxy.get_node_or_null("CollisionShape2D")
			
			if t_col_node and p_col_node:
				if p_col_node.shape == null:
					p_col_node.shape = RectangleShape2D.new()
				else:
					# Left/Rightで共有しないように複製
					p_col_node.shape = p_col_node.shape.duplicate()
				
				# 内部の判定サイズに、キャラ全体の表示倍率(final_scale)を掛ける
				p_col_node.shape.size = t_col_node.shape.size * final_scale
		# ==========================================================
		if timer_label.has_method("setup_collision_shape"):
			timer_label.setup_collision_shape()
		
		show()
		char_area.monitoring = true
		char_area.monitorable = true
	else:
		hide()
		char_area.monitoring = false
		char_area.monitorable = false
		# テクスチャがない場合（非表示）、プロキシの判定も無効化しておくと安全です
		if char_proxy:
			var p_col = char_proxy.get_node("CollisionShape2D")
			if p_col: p_col.disabled = true

	update_timer_display()
	update_timer()
	if texture:
		# プロキシが生きていれば有効化
		if char_proxy:
			var p_col = char_proxy.get_node("CollisionShape2D")
			if p_col: p_col.disabled = false
			
		start_dripping_loop()
		show()
		
# 毎フレーム main_game.gd から呼ばれるタイマー更新関数
# --- タイマー表示制御 ---
func update_timer():
	var key = get_current_key()
	if key != "" and Global.death_data.has(key):
		timer_label.target_char_id = key
		# ここではまだ show() しない（マウスが乗った時に出すため）
	else:
		timer_label.hide()
		
# --- マウス制御 ---

# CharacterArea (キャラ用) の mouse_entered シグナルに接続
func _on_mouse_entered():
	if not is_visible_in_tree(): return
	if get_current_key() != "":
		timer_label.show()
		Global.discover_death_time(get_current_key())
		
# CharacterArea (キャラ用) の mouse_exited シグナルに接続
func _on_mouse_exited():
	# 以下の状態の時は、マウスがキャラから外れてもタイマーを消さない
	if timer_label.is_changing: return    # 運命書き換え（グリッチ）演出中
	if timer_label.is_captured: return    # マウスで捕まえている最中
	
	# それ以外（ただマウスを離しただけ）なら隠す
	timer_label.hide()
# タイマーの数値と色を更新する関数


func update_timer_display():
	var key = get_current_key()
	if key == "":
		timer_label.hide()
		return
		
# ID番号(int)をGlobalの辞書キー(String)に変換するヘルパー関数
func get_current_key() -> String:
	match current_char_id:
		1: return "Kokorone"
		2: return "Homura"
		3: return "Rei"
		# モブ(一般人)の場合はID:4などを割り当てる予定
		# 4: return "Mob" 
	return ""

# --- 演出用（既存のまま） ---
# 明るさを変える関数
func set_focus(is_active: bool):
	var target_color = Color.WHITE # アクティブなら元の色
	if not is_active:
		target_color = Color(0.5, 0.5, 0.5) # 非アクティブならグレー（暗く）
	
	# 0.2秒かけてじわっと色を変える演出
	var tween = create_tween()
	tween.tween_property(self, "modulate", target_color, 0.2)


# マウスが乗っていて（ラベルが見えていて）、かつデータがあるなら時間を更新し続ける
func _process(_delta):
	if not char_proxy : return

	# --- A. 立ち絵プロキシの同期 ---
	# 位置だけを同期（サイズは display 関数で設定済みなので触らない）
	char_proxy.global_position = self.global_position

	# --- B. タイマープロキシの同期 ---
	# タイマー（TimerLabel）が表示されている時だけ、その位置とサイズを同期する
	if timer_label.visible and timer_proxy:
		# 掴んでいる間は、本体(timer_label)をマウスに追従させる
		# ==========================================================
		if timer_label.get("is_captured"):
			# ラベル本体をマウス位置へ（これで本体がマウスに付いてくる）
			timer_label.global_position = get_global_mouse_position()
		# 計算をやり直すのではなく、すでに頭上に移動している timer_label の 
		# global_position をそのままコピーするのが一番正確です。
		timer_proxy.global_position = timer_label.global_position

		# 当たり判定のノード取得
		var t_col = timer_label.get_node_or_null("CanvasGroup/TimerArea/TimerCollision")
		var p_col = timer_proxy.get_node_or_null("CollisionShape2D")
		
		if t_col and p_col:
			# プロキシの形状をユニークにする（他と混ざらないように）
			if p_col.shape == null:
				p_col.shape = RectangleShape2D.new()
			elif not p_col.shape.is_class("RectangleShape2D"): # 万が一のリセット
				p_col.shape = RectangleShape2D.new()
			
			# サイズの同期
			# 内部タイマーのサイズ * CanvasGroupのスケール * 全体のスケール
			var internal_scale = timer_label.get_node("CanvasGroup").scale
			p_col.shape.size = t_col.shape.size * internal_scale * self.scale
			
func splash_water(pos: Vector2):
	# CanvasGroupの方にあるマテリアルを取得するように修正
	var mat = timer_label.get_node("CanvasGroup").material as ShaderMaterial
	if not mat: return
	
	mat.set_shader_parameter("droplet_center", pos)
	
	var tween = create_tween()
	# シェーダーのパラメータに合わせてアニメーション
	tween.tween_property(mat, "shader_parameter/droplet_size", 1.0, 0.8).from(0.0).set_trans(Tween.TRANS_SINE)

func start_dripping_loop():
	if is_dripping: return 
	is_dripping = true
	
	while is_visible_in_tree():
		var wait_time = randf_range(0.8, 1.5)
		await get_tree().create_timer(wait_time).timeout
		
		# タイマーが表示されている時だけ波紋を出す
		if timer_label.visible:
			var random_pos = Vector2(randf_range(0.2, 0.8), randf_range(0.2, 0.8))
			splash_water(random_pos)
	
	is_dripping = false

# プロキシがクリックされた時の処理
func _on_timer_proxy_input_event(viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# ★重要：ここでイベントを「消費」する
			# ■ 修正後（イベントが発生した「親のViewport」に対して命令する）
			viewport.set_input_as_handled()
			
			if timer_label.visible:
				# タイマー側の「運命書き換え」を実行
				timer_label.handle_proxy_click()
# マウスが入った時
func _on_timer_proxy_mouse_entered():
	Global.is_hovering_proxy = true # ★追加
	timer_label._on_area_2d_mouse_entered()

# マウスが出た時
func _on_timer_proxy_mouse_exited():
	Global.is_hovering_proxy = false # ★追加
	timer_label._on_area_2d_mouse_exited()
