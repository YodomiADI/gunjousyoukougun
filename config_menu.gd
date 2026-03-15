extends CanvasLayer

@onready var master_slider = $BackgroundPanel/MasterSlider
@onready var bgm_slider = $BackgroundPanel/BGMSlider
@onready var se_slider = $BackgroundPanel/SESlider

@onready var master_label = $BackgroundPanel/MasternamePanel
@onready var bgm_label = $BackgroundPanel/BGMnamePanel
@onready var se_label = $BackgroundPanel/SEnamePanel

signal menu_closed # 画面が閉じたことを知らせるシグナル

func _ready():
	# 画面を開いた時、スライダーの位置を現在のGlobalの値に合わせる
	master_slider.value = Global.master_volume
	bgm_slider.value = Global.bgm_volume
	se_slider.value = Global.se_volume
	
	# ラベルの表示も初期状態に合わせる
	update_labels()
	
	# 最初は非表示にしておく
	hide()
	
# --- すべてのラベルを更新する便利関数 ---
func update_labels():
	master_label.text = str(int(master_slider.value)) + "%"
	bgm_label.text = str(int(bgm_slider.value)) + "%"
	se_label.text = str(int(se_slider.value)) + "%"
	
# --- MasterSliderの「value_changed」シグナル ---
# ※エディタからMasterSliderのシグナルをここに接続してください！
func _on_master_slider_value_changed(value: float):
	Global.master_volume = value
	Global.apply_volumes()
	master_label.text = str(int(value)) + "%" # ラベルを更新
	
# --- BGMSliderの「value_changed」シグナルを接続 ---
func _on_bgm_slider_value_changed(value: float):
	Global.bgm_volume = value
	Global.apply_volumes()
	bgm_label.text = str(int(value)) + "%" # ラベルを更新

# --- SESliderの「value_changed」シグナルを接続 ---
func _on_se_slider_value_changed(value: float):
	Global.se_volume = value
	Global.apply_volumes()
	se_label.text = str(int(value)) + "%" # ラベルを更新
	
	# もし「SEの音量を変えた時に、ピコッと確認音を鳴らしたい」場合は
	# ここで $SEPlayer.play() などをしてあげる
	
# 閉じるボタンが押された時の処理
func _on_close_button_pressed():
	hide()
	menu_closed.emit() # 閉じたよ！と合図を出す
