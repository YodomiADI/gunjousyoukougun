# character_display.gd の1行目に追加
class_name CharacterDisplay
# character_display.gd
extends Node2D

# --- エディタのインスペクターから、スロットごとの基本倍率を設定できるようにする ---
@export var base_scale: float = 1.0

@onready var sprite = $Sprite2D # 名前に注意！Sprite2D か Sprite か
@onready var timer_label = $TimerLabel
@onready var click_area = $Area2D
@onready var collision_shape = $Area2D/CollisionShape2D # ← 追加: シェイプにアクセスするため取得

var current_character_name: String = ""
var current_char_id: int = 0

func _ready():
	timer_label.hide() # 最初は隠しておく
	
	# マウス信号の接続
	# エディタで接続しても良いですが、コードで書くと確実です
	click_area.mouse_entered.connect(_on_mouse_entered)
	click_area.mouse_exited.connect(_on_mouse_exited)

# main_game.gd から呼ばれる関数名
func display(display_name: String, texture: Texture2D, char_id: int = 0, offset_y: float = -40.0, char_scale: float = 1.0, b_scale: float = 1.0):
	current_character_name = display_name
	current_char_id = char_id
	
	# 素材本来の大きさ(b_scale) と 演出用の大きさ(char_scale) を掛け合わせる
	var final_scale = b_scale * char_scale
	
	if is_visible_in_tree():
		# すでに画面に表示されている場合：
		# 表情差分やズーム演出なので、Tweenでじわっと変える
		var scale_tween = create_tween()
		scale_tween.tween_property(self, "scale", Vector2(final_scale, final_scale), 0.2).set_trans(Tween.TRANS_SINE)
	else:
		# 今から初めて表示される場合：
		# Tweenを使わず、即座にサイズを決定する（これで「ぐっと縮む」のを防ぐ）
		self.scale = Vector2(final_scale, final_scale)
	

	if texture:
		sprite.texture = texture
		
		# --- 位置とサイズの自動調整 ---
	# 1. 画像のサイズを取得 (var宣言はここ1回だけにする)
		var tex_size = texture.get_size()
		
		# 2. 当たり判定（CollisionShape2D）を画像サイズに合わせる
		if collision_shape.shape == null:
			collision_shape.shape = RectangleShape2D.new()
		collision_shape.shape.size = tex_size
		
		# 3. 死期ラベルを「頭の少し上」に自動配置
		# Spriteの中心が(0,0)の場合、上端は -(高さ / 2)。そこから offset_y 分ずらす
		timer_label.position.y = -(tex_size.y / 2.0) + offset_y
		# -------------------------------------------------------
		show()
		# ★重要：表示されている時だけ当たり判定を有効にする
		click_area.monitoring = true
		click_area.monitorable = true
	else:
		hide()
		# 非表示なら当たり判定も消す（透明なスロットに反応しないように）
		click_area.monitoring = false
		click_area.monitorable = false
		
	# マウスがすでに乗っている状態で画像が変わった場合のために更新
	update_timer_display()
	
# ---表示した瞬間にタイマーの文字を更新し、表示・非表示を判定する ---
	update_timer()
# 毎フレーム main_game.gd から呼ばれるタイマー更新関数
func update_timer():
# IDに応じて Global のどの数値を参照するか決める
	var time_key = ""
	match current_char_id:
		1: time_key = "Kokorone"
		2: time_key = "Homura"
		3: time_key = "Rei"
	
	if time_key != "" and Global.death_timers.has(time_key):
		timer_label.text = Global.format_death_time(Global.death_timers[time_key])
		timer_label.show()
	else:
		timer_label.hide()
		
# --- ★ここからが新機能：マウス制御 ---

# マウスが乗った時
func _on_mouse_entered():
	if not is_visible_in_tree(): return # 見えてなければ無視
	
	update_timer_display()
	
	# キャラIDが有効なら表示する
	if get_current_key() != "":
		timer_label.show()
		
		# 【手記連携】発見済みフラグを立てる
		Global.discover_death_time(get_current_key())

# マウスが離れた時
func _on_mouse_exited():
	timer_label.hide()

# タイマーの数値と色を更新する関数
func update_timer_display():
	var key = get_current_key()
	if key == "":
		timer_label.hide()
		return
		
	# 1. Globalから「現在の数値（赤優先）」を取得
	var time_val = Global.get_current_death_time(key)
	timer_label.text = Global.format_death_time(time_val)
	
	# 2. 赤文字データの有無を確認して色を変える
	var data = Global.death_data.get(key)
	if data and data["red"] > 0:
		timer_label.modulate = Color(1, 0.2, 0.2) # 赤色
	else:
		timer_label.modulate = Color.WHITE      # 白色

# ID番号(int)をGlobalの辞書キー(String)に変換するヘルパー関数
func get_current_key() -> String:
	match current_char_id:
		1: return "Kokorone"
		2: return "Homura"
		3: return "Rei"
		# モブ(一般人)の場合はID:4などを割り当てる予定
		# 4: return "Mob" 
	return ""

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
	if timer_label.visible:
		update_timer_display()
