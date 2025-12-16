extends CanvasLayer# ルートノードがCanvasLayerならここは extends CanvasLayer になります

# タイトル画面のファイルパス（※自分のファイル名に合わせて書き換えてください！）
const TITLE_SCENE_PATH =  "res://title_screen.tscn"


# 2つのコンテナを取得します（パスは実際の構成に合わせて修正してください）
@onready var main_buttons_container = $Control/Panel/MainButtons
@onready var save_slots_menu = $Control/Panel/SaveSlotsMenu

# スロットボタンの配列
@onready var slot_buttons = [
	$Control/Panel/SaveSlotsMenu/Slot1_Button,
	$Control/Panel/SaveSlotsMenu/Slot2_Button,
	$Control/Panel/SaveSlotsMenu/Slot3_Button
]
# ★追加: SEPlayerを取得
@onready var se_player = $SEPlayer # エディタでAudioStreamPlayerを追加しておくこと

# ★追加: 音源のロード
var sound_hover = preload("res://SE/時計の針マウスオーバー.mp3") # ※ホバー用の音
var sound_click = preload("res://SE/シ.mp3")      # ※クリック用の音

func _ready():
	# ゲーム開始時は見えないように隠しておく
	visible = false
	# 初期状態：メインを表示、セーブ画面を隠す
	main_buttons_container.visible = true
	save_slots_menu.visible = false
	# ボタンのシグナルをコードで接続する場合（エディタで接続してもOKです）
	# 引数を持たせるために bind を使っています
	for i in range(slot_buttons.size()):
		var btn = slot_buttons[i]
		# slot_id は 1 から始めたいので i + 1 を渡す
		if !btn.pressed.is_connected(_on_save_slot_pressed):
			btn.pressed.connect(_on_save_slot_pressed.bind(i + 1))
	#SEのセットアップを実行
	setup_pause_sound_effects()
# ポーズ画面の全ボタンにSEを設定する関数
func setup_pause_sound_effects():
	# ポーズ画面にあるボタンをすべてリストアップする
	# ※階層が変わった場合はパスを修正してください
	var all_buttons = [
		$Control/Panel/MainButtons/go_back_game_Button,
		$Control/Panel/MainButtons/ToSaveMenuButton,
		$Control/Panel/MainButtons/go_to_title_Button,
		$Control/Panel/SaveSlotsMenu/BackButton
	] + slot_buttons # スロットボタン配列も結合
	
	for btn in all_buttons:
		# マウスオーバー時 -> ホバー音
		if !btn.mouse_entered.is_connected(play_se):
			btn.mouse_entered.connect(play_se.bind(sound_hover))
			
		# クリック時 -> 決定音
		# 注意: 既にシグナル接続されているボタンも多いですが、
		# play_seは「音を鳴らすだけ」の独立した関数として追加接続してOKです
		if !btn.pressed.is_connected(play_se):
			btn.pressed.connect(play_se.bind(sound_click))

# SE再生用関数
func play_se(stream_data):
	# エラー回避：ノードがシーンツリーから削除されている（画面遷移中など）場合は何もしない
	if not is_inside_tree():
		return

	if se_player and stream_data:
		se_player.stream = stream_data
		se_player.play()

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()
# ポーズ状態を切り替える関数
func toggle_pause():
	var tree = get_tree()
	
	# 現在のポーズ状態を反転させる（trueならfalseに、falseならtrueに）
	tree.paused = !tree.paused
	
	# メニューの表示状態もポーズ状態に合わせる
	# ポーズ中(true)なら表示(true)、動いてる(false)なら非表示(false)
	visible = tree.paused

	if visible:
		# ポーズを開いたときは必ず「メインメニュー」から始める
		switch_to_main_menu()

# スロットボタンの表示を更新する関数
func update_save_slots_display():
	for i in range(slot_buttons.size()):
		var slot_id = i + 1
		var btn = slot_buttons[i]
		var data = Global.get_slot_info(slot_id)
		
		if data.is_empty():
			# データがない場合
			btn.text = "スロット %d : ---- データなし ----" % slot_id
		else:
			# データがある場合
			# Global.gd で定義した日本語の章の名前を取得
			var ch_name = Global.chapter_names.get(data["chapter_id"], data["chapter_id"])
			# 時間をフォーマット
			var time_str = Global.format_time(data.get("play_time", 0))
			
			# 表示テキストを作成
			# 例: "スロット 1 : 第一章 / 00:15:30"
			btn.text = "スロット %d : %s / %s" % [slot_id, ch_name, time_str]

# --- ボタン処理 ---

# 「セーブする」ボタンが押されたとき
# エディタでこのボタンの pressed シグナルをこの関数に接続してください
func _on_to_save_menu_button_pressed():
	switch_to_save_menu()

#  セーブ画面の「戻る」ボタンが押されたとき
# エディタでこのボタンの pressed シグナルをこの関数に接続してください
func _on_back_button_pressed():
	switch_to_main_menu()

# セーブスロットが押されたときの処理
func _on_save_slot_pressed(slot_id):
	# セーブを実行
	Global.save_game(slot_id)
	
	# ボタンの表示を即座に更新（「データなし」→「現在のデータ」へ書き換わる）
	update_save_slots_display()
	
	print("スロット %d にセーブしました" % slot_id)
	# 必要なら「セーブしました！」というポップアップを出しても良いでしょう

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

# メインメニューを表示する
func switch_to_main_menu():
	main_buttons_container.visible = true
	save_slots_menu.visible = false

# セーブ画面を表示する
func switch_to_save_menu():
	main_buttons_container.visible = false
	save_slots_menu.visible = true
	# セーブ画面を開いたタイミングで表示内容を更新
	update_save_slots_display()
