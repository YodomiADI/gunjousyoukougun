extends Node2D

@export var target_char_id: String = "Player"

@onready var digits = {
	"year_10": $Year10, "year_01": $Year1,
	"month_10": $Month10, "month_01": $Month1,
	"day_10": $Day10, "day_01": $Day1,
	"hour_10": $Hour10, "hour_01": $Hour1,
	"min_10": $Min10, "min_01": $Min1,
	"sec_10": $Sec10, "sec_01": $Sec1
}

@onready var colons = [] # 動的に取得する形にするとミスが減ります

func _ready():
	# Colon1, Colon2... という名前のノードを自動で探してリストに入れる
	for child in get_children():
		if child.name.begins_with("Colon") and child is AnimatedSprite2D:
			colons.append(child)
			if child.sprite_frames.has_animation("colon"):
				child.play("colon")

func _process(_delta):
	var total_seconds = Global.get_current_death_time(target_char_id)
	var s = int(total_seconds)
	
	# 整数で計算（小数点誤差を防ぐ）
	@warning_ignore("integer_division")
	var years = s / 31536000
	s %= 31536000
	@warning_ignore("integer_division")
	var months = s / 2592000
	s %= 2592000
	@warning_ignore("integer_division")
	var days = s / 86400
	s %= 86400
	@warning_ignore("integer_division")
	var hours = s / 3600
	s %= 3600
	@warning_ignore("integer_division")
	var minutes = s / 60
	var seconds = s % 60
	
	update_digit_pair("year", years)
	update_digit_pair("month", months)
	update_digit_pair("day", days)
	update_digit_pair("hour", hours)
	update_digit_pair("min", minutes)
	update_digit_pair("sec", seconds)

func update_digit_pair(key_prefix: String, value: int):
	@warning_ignore("integer_division")
	var v10 = (value / 10) % 10
	var v01 = value % 10
	set_sprite_anim(digits[key_prefix + "_10"], v10)
	set_sprite_anim(digits[key_prefix + "_01"], v01)

func set_sprite_anim(sprite: AnimatedSprite2D, num: int):
	if not sprite: return
	var anim_name = str(num)
	if sprite.animation != anim_name:
		if sprite.sprite_frames.has_animation(anim_name):
			sprite.play(anim_name)
