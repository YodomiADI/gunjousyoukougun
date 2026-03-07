extends CanvasLayer

@onready var bgm_slider = $BackgroundPanel/BGMSlider
@onready var se_slider = $BackgroundPanel/SESlider
signal menu_closed # 画面が閉じたことを知らせるシグナル

func _ready():
	# 画面を開いた時、スライダーの位置を現在のGlobalの値に合わせる
	bgm_slider.value = Global.bgm_volume
	se_slider.value = Global.se_volume
	# 最初は非表示にしておく
	hide()
	
# --- BGMSliderの「value_changed」シグナルを接続 ---
func _on_bgm_slider_value_changed(value: float):
	Global.bgm_volume = value
	Global.apply_volumes()

# --- SESliderの「value_changed」シグナルを接続 ---
func _on_se_slider_value_changed(value: float):
	Global.se_volume = value
	Global.apply_volumes()
	
	# もし「SEの音量を変えた時に、ピコッと確認音を鳴らしたい」場合は
	# ここで $SEPlayer.play() などをしてあげる
	
# 閉じるボタンが押された時の処理
func _on_close_button_pressed():
	hide()
	menu_closed.emit() # 閉じたよ！と合図を出す
