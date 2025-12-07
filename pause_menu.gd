extends CanvasLayer# ルートノードがCanvasLayerならここは extends CanvasLayer になります

# タイトル画面のファイルパス（※自分のファイル名に合わせて書き換えてください！）
const TITLE_SCENE_PATH =  "res://title_screen.tscn"

func _ready():
	# ゲーム開始時は見えないように隠しておく
	visible = false

func _input(event):
	print("Input detected: ", event.as_text())
	# Escキー（ui_cancel）が押されたらポーズ切り替え
	if event.is_action_pressed("ui_cancel"):
		print("--- ESC KEY PRESSED! ---")
		toggle_pause()

# ポーズ状態を切り替える関数
func toggle_pause():
	var tree = get_tree()
	
	# 現在のポーズ状態を反転させる（trueならfalseに、falseならtrueに）
	tree.paused = !tree.paused
	
	# メニューの表示状態もポーズ状態に合わせる
	# ポーズ中(true)なら表示(true)、動いてる(false)なら非表示(false)
	visible = tree.paused

# 「ゲームに戻る」ボタンが押されたとき
func _on_go_back_game_button_pressed() -> void:
	pass # Replace with function body.
	toggle_pause()
	
	
# 「タイトルへ戻る」ボタンが押されたとき
func _on_go_to_title_button_pressed() -> void:
	pass # Replace with function body.
		# ★最重要：シーン移動する前に必ずポーズを解除する！
	toggle_pause() 
	
	# タイトル画面へ移動
	get_tree().change_scene_to_file(TITLE_SCENE_PATH)
