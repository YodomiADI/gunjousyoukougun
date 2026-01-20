#DeathCounter_design.gd
extends AnimatedSprite2D

# 監視するキャラクターのID (Global.death_data のキーと一致させる)
@export var character_id: String = "Kokorone"

# 何の位を表示するか (1なら1の位、10なら10の位)
@export var digit_place: int = 1

var last_digit: int = -1

func _process(_delta):
	# 1. Global.gd から現在の残り秒数を取得
	var total_seconds = Global.get_current_death_time(character_id)
	
	# 2. 表示すべき「位」の数字を抽出
	# 例：123秒の「1の位」は 3、 「10の位」は 2
	var current_digit = int(total_seconds / digit_place) % 10
	
	# 3. 数字が変わったときだけアニメーションを再生
	if current_digit != last_digit:
		last_digit = current_digit
		play_digit_animation(current_digit)

func play_digit_animation(digit: int):
	var anim_name = str(digit)
	if sprite_frames.has_animation(anim_name):
		# すでに再生中のアニメーションが同じ数字なら何もしない
		if animation != anim_name:
			play(anim_name)
