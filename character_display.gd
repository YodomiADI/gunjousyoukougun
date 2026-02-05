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

# ※ TimerArea（タイマーが逃げる用）は、timer_label.gd側で処理するため
#   このスクリプトからは触らないようにして、混線を防ぎます。

var current_character_name: String = ""
var current_char_id: int = 0

func _ready():
	timer_label.hide() # 最初は隠しておく
	
	
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
		# 【重要】キャラ用の当たり判定を立ち絵のサイズに合わせる
		if char_collision.shape == null:
			char_collision.shape = RectangleShape2D.new()
		char_collision.shape.size = tex_size
		# 3. 死期ラベルを「頭の少し上」に自動配置
		# Spriteの中心が(0,0)の場合、上端は -(高さ / 2)。そこから offset_y 分ずらす
		timer_label.position.y = -(tex_size.y / 2.0) + offset_y
		# -------------------------------------------------------
		show()
		# ★重要：表示されている時だけ当たり判定を有効にする
		char_area.monitoring = true
		char_area.monitorable = true
	else:
		hide()
		# 非表示なら当たり判定も消す（透明なスロットに反応しないように）
		char_area.monitoring = false
		char_area.monitorable = false
		
	# マウスがすでに乗っている状態で画像が変わった場合のために更新
	update_timer_display()
	
# ---表示した瞬間にタイマーの文字を更新し、表示・非表示を判定する ---
	update_timer()
	if texture:
		# キャラクターが表示されるタイミングでループを開始！
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
	# タイマーが「キャプチャ（吸着）状態」でない時だけ隠す
	# ※ もしマウスで捕まえている最中にキャラからマウスが外れても、
	#    タイマーが消えないように timer_label 側に確認させるのがスマートです。
	if not timer_label.get("is_changing"): # 運命書き換え中も消さない
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
	if timer_label.visible:
		update_timer_display()

func splash_water(pos: Vector2):
	var mat = timer_label.material as ShaderMaterial
	if not mat: return
	
	mat.set_shader_parameter("droplet_center", pos)
	
	var tween = create_tween()
	# じわっと広がる
	tween.tween_property(mat, "shader_parameter/droplet_size", 0.4, 0.6).set_trans(Tween.TRANS_SINE)
	# ゆっくり乾いて消える
	tween.tween_property(mat, "shader_parameter/droplet_size", 0.0, 1.2).set_trans(Tween.TRANS_QUAD).set_delay(0.2)

func start_dripping_loop():
	# 少しランダムな時間を待つ（0.8秒〜1.5秒の間）
	var wait_time = randf_range(0.3, 0.6)
	
	# タイマーを作成して待機
	await get_tree().create_timer(wait_time).timeout
	
	# このノードが表示されている時だけ実行（非表示の時は止める）
	if is_visible_in_tree():
		# ランダムな位置に水滴を落とす (0.1〜0.9の範囲にすると文字からはみ出しにくい)
		var random_pos = Vector2(randf_range(-0.4, 0.6), randf_range(0.1, 0.9))
		splash_water(random_pos)
		
		# 自分自身をもう一度呼んでループさせる（再帰呼び出し）
		start_dripping_loop()
