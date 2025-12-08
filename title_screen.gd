extends Control

# --- UIノードへの参照 ---
# メインメニュー（はじめから、ロード、終了ボタンがある親ノード）
@onready var main_menu = $MainMenu
# ロードメニュー（各スロットボタンがある親ノード）
@onready var load_menu = $LoadMenu

# --- ロード用ボタンの配列 ---
# 0番目はオートセーブ、1～3番目は手動セーブに対応させます
# エディタ上のノードパスに合わせて書き換えてください
@onready var load_slot_buttons = [
	$LoadMenu/VBoxContainer/AutoSaveButton, # Slot 0 (Auto Save)
	$LoadMenu/VBoxContainer/Slot1Button, # Slot 1
	$LoadMenu/VBoxContainer/Slot2Button, # Slot 2
	$LoadMenu/VBoxContainer/Slot3Button# Slot 3
]

func _ready():
	# 初期化：メインメニューを表示し、ロード画面を隠す
	main_menu.visible = true
	load_menu.visible = false
	
	# ロードボタンのシグナル接続
	for i in range(load_slot_buttons.size()):
		var btn = load_slot_buttons[i]
		# Global.gdに合わせ、i=0はオートセーブ、i=1以降は通常セーブとして扱います
		if !btn.pressed.is_connected(_on_slot_button_pressed):
			btn.pressed.connect(_on_slot_button_pressed.bind(i))
	
	# ★注: $VBoxContainer/ContinueButton.disabled = true の行は、
	# UI構成が不明確なため、エラーが出る場合は削除するか、正しいパスに修正してください。
	# 「つづきから」ボタンがあるなら、その制御ロジックを残します。
	# if not FileAccess.file_exists(Global.SAVE_PATH_TEMPLATE % Global.AUTO_SAVE_SLOT):
	# 	# もしContinueButtonがあれば、ここで無効化する
	# 	pass 
	pass


# --- ボタン処理（メインメニュー） ---

# 「はじめから」 (統合された定義)
func _on_start_button_pressed():
	Global.reset_game_progress()
	get_tree().change_scene_to_file("res://main_game.tscn")

# 「ロード（つづきから選択）」ボタンを押したとき
func _on_load_menu_button_pressed():
	update_load_slots_display()
	switch_to_load_menu()

# 「終了」 (統合された定義)
func _on_quit_button_pressed():
	get_tree().quit()

# --- ボタン処理（ロードメニュー） ---

# 各スロットボタンが押されたときの共通処理
func _on_slot_button_pressed(slot_id):
	# ロードを試みる
	if Global.load_game(slot_id):
		# 成功したらゲーム画面へ
		print("スロット", slot_id, "をロードしてゲームを開始します")
		get_tree().change_scene_to_file("res://main_game.tscn")
	else:
		# データがない、ロード失敗などの場合
		print("ロードに失敗しました")

# ロード画面の「戻る」ボタン
func _on_back_button_pressed():
	switch_to_main_menu()

# --- 画面切り替え・表示更新ロジック ---

func switch_to_main_menu():
	main_menu.visible = true
	load_menu.visible = false

func switch_to_load_menu():
	main_menu.visible = false
	load_menu.visible = true

# スロットボタンの表示（テキスト・有効無効）を更新する
func update_load_slots_display():
	for i in range(load_slot_buttons.size()):
		var slot_id = i # 配列のインデックスとスロットIDを一致させます（0=オートセーブ）
		var btn = load_slot_buttons[i]
		
		# Globalからデータを取得（ファイルがない場合は空の辞書が返る）
		var data = Global.get_slot_info(slot_id)
		
		if data.is_empty():
			# データなし
			if slot_id == 0:
				btn.text = "オートセーブ : -- データなし --"
			else:
				btn.text = "スロット %d : -- データなし --" % slot_id
			
			# データがないボタンは押せないようにする
			btn.disabled = true
		else:
			# データあり
			var ch_name = Global.chapter_names.get(data["chapter_id"], data["chapter_id"])
			var time_str = Global.format_time(data.get("play_time", 0))
			
			if slot_id == 0:
				btn.text = "オートセーブ : %s / %s" % [ch_name, time_str]
			else:
				btn.text = "スロット %d : %s / %s" % [slot_id, ch_name, time_str]
			
			# データがあるので押せるようにする
			btn.disabled = false


func _on_load_button_pressed() -> void:
	pass # Replace with function body.


func _on_auto_save_button_pressed() -> void:
	pass # Replace with function body.


func _on_slot_1_button_pressed() -> void:
	pass # Replace with function body.


func _on_slot_2_button_pressed() -> void:
	pass # Replace with function body.


func _on_slot_3_button_pressed() -> void:
	pass # Replace with function body.
