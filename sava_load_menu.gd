# save_load_menu.gd
extends Control

var is_save_mode: bool = true # trueならセーブ、falseならロードとして動作

func _ready():
	# モードによってタイトルを変えるなどの処理
	if is_save_mode:
		$Title.text = "セーブデータを選択"
	else:
		$Title.text = "ロードデータを選択"

func _on_slot_1_pressed():
	execute_action(1)

func _on_slot_2_pressed():
	execute_action(2)

func _on_slot_3_pressed():
	execute_action(3)

func execute_action(slot_id: int):
	if is_save_mode:
		Global.save_game(slot_id)
		# セーブが終わったら閉じる
		queue_free() 
	else:
		if Global.load_game(slot_id):
			print("ロード成功")
		else:
			print("データがありません")

func _on_back_button_pressed():
	queue_free() # 画面を閉じる
