# character_display.gd の1行目に追加
class_name CharacterDisplay
# character_display.gd
extends Node2D

# --- エディタのインスペクターから、スロットごとの基本倍率を設定できるようにする ---
@export var base_scale: float = 1.0

@onready var sprite = $Sprite2D # 名前に注意！Sprite2D か Sprite か
@onready var timer_label = $TimerLabel

var current_character_name: String = ""
var current_char_id: int = 0

# ★ ここが重要！ main_game.gd から呼ばれる関数名
func display(display_name: String, texture: Texture2D, char_id: int = 0, offset: Vector2 = Vector2(0, -450), char_scale: float = 1.0, b_scale: float = 1.0):
	current_character_name = display_name
	current_char_id = char_id
	
	# ラベルの位置を、リソースで設定したオフセットに変える
	timer_label.position = offset
	
	# 重要：素材本来の大きさ(b_scale) と 演出用の大きさ(char_scale) を掛け合わせる
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
	
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(final_scale, final_scale), 0.2).set_trans(Tween.TRANS_SINE)
	if texture:
		sprite.texture = texture
		show()
	else:
		hide()
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
# 明るさを変える関数
func set_focus(is_active: bool):
	var target_color = Color.WHITE # アクティブなら元の色
	if not is_active:
		target_color = Color(0.5, 0.5, 0.5) # 非アクティブならグレー（暗く）
	
	# 0.2秒かけてじわっと色を変える演出
	var tween = create_tween()
	tween.tween_property(self, "modulate", target_color, 0.2)
