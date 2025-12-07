extends Control

# 「はじめから」ボタンが押されたときの処理
func _on_start_button_pressed():
	# Globalのリセット機能を使用し、章のIDも含めて初期化する
	# これでcurrent_chapter_idが"prologue"に戻り、main_gameへ遷移します。
	Global.reset_game_progress()
	# ゲーム本編のシーン（例: game.tscn）に切り替える
	get_tree().change_scene_to_file("res://main_game.tscn")

# 「終了」ボタンが押されたときの処理
func _on_quit_button_pressed():
	get_tree().quit()

func _ready():
	# セーブファイルが存在するかチェック
	if not FileAccess.file_exists(Global.SAVE_PATH):
		# セーブがないなら「つづきから」ボタンを押せないようにする
		$VBoxContainer/ContinueButton.disabled = true

# 「つづきから」ボタンが押されたとき
func _on_continue_button_pressed():
	# ロード処理を実行、Globalに変数をセット
	if Global.load_game():
		# ロード成功ならゲーム画面へ遷移
		get_tree().change_scene_to_file("res://main_game.tscn")
