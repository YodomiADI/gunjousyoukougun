extends Control

# --- UIノードへの参照 ---
# メインメニュー（はじめから、ロード、終了ボタンがある親ノード）
@onready var main_menu = $MainMenu
# ロードメニュー（各スロットボタンがある親ノード）
@onready var load_menu = $LoadMenu

# 確認ダイアログと削除モードボタン
@onready var delete_confirm_dialog = $DeleteConfirmDialog
@onready var delete_mode_button = $LoadMenu/VBoxContainer/DeletModeButton

# 効果音用のプレイヤーを取得
@onready var se_player = $SEPlayer

# 効果音のファイルをロード（※ファイルパスは実際の場所に合わせて書き換えてください！）
var sound_si = preload("res://SE/シ.mp3") # 「シ」
var scale_sounds = [
	preload("res://SE/ド.mp3"), # 「ド」 AutoSaveButton用
	preload("res://SE/レ.mp3"), # 「レ」 Slot1Button用
	preload("res://SE/ミ.mp3"), # 「ミ」 Slot2Button用
	preload("res://SE/ファ.mp3"), # 「ファ」 Slot3Button用
	preload("res://SE/ソ.mp3")  # 「ソ」 BackButton用
]
# クリック（決定）用の音をロード
var sound_click = preload("res://SE/時計の針マウスオーバー.mp3")
# --- ロード用ボタンの配列 ---
# 0番目はオートセーブ、1～3番目は手動セーブに対応させます
# エディタ上のノードパスに合わせて書き換えてください
@onready var load_slot_buttons = [
	$LoadMenu/VBoxContainer/AutoSaveButton, # Slot 0 (Auto Save)
	$LoadMenu/VBoxContainer/Slot1Button, # Slot 1
	$LoadMenu/VBoxContainer/Slot2Button, # Slot 2
	$LoadMenu/VBoxContainer/Slot3Button# Slot 3
]

# ロード画面の「戻る」ボタンも取得（音階の「ソ」を鳴らすため）
@onready var load_back_button = $LoadMenu/VBoxContainer/BackButton

# 削除しようとしているスロット番号を一時保存する変数
var pending_delete_slot_id: int = -1

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
	
	#  ダイアログの「OK(削除)」が押されたときのシグナル接続
	if !delete_confirm_dialog.confirmed.is_connected(_on_delete_confirmed):
		delete_confirm_dialog.confirmed.connect(_on_delete_confirmed)
		
	#  削除モードボタンを押したときの表示更新（任意）
	if !delete_mode_button.toggled.is_connected(_on_delete_mode_toggled):
		delete_mode_button.toggled.connect(_on_delete_mode_toggled)
	
	# 効果音（SE）のセットアップ
	setup_sound_effects()
	
	# すべてのボタンに音を割り当てる関数
func setup_sound_effects():
	# 1. タイトル画面のボタン（Start, Load, Quit） -> 「シ」の音
	# VBoxContainerの中にあるボタンを取得して設定します
	var title_buttons = [
		$MainMenu/StartButton,
		$MainMenu/LoadButton, # メインメニューにある「つづきから」ボタン
		$MainMenu/QuitButton
	]
	
	for btn in title_buttons:
		# マウスが入ったとき（ホバー）
		if !btn.mouse_entered.is_connected(play_se):
			btn.mouse_entered.connect(play_se.bind(sound_si))
		# 押したとき
		# クリック時は「決定音」 (sound_click)
		if !btn.pressed.is_connected(play_se):
			btn.pressed.connect(play_se.bind(sound_click))


	# 2. ロードメニューのボタン（AutoSave～Back） -> 「ドレミファソ」
	# 既存のload_slot_buttons（4つ）に BackButton（1つ）を足してリストを作ります
	var scale_buttons = load_slot_buttons + [load_back_button]
	
	for i in range(scale_buttons.size()):
		# scale_soundsの数が足りているか確認
		if i < scale_sounds.size():
			var btn = scale_buttons[i]
			var sound = scale_sounds[i]
			
			# マウスが入ったとき（ホバー）
			if !btn.mouse_entered.is_connected(play_se):
				btn.mouse_entered.connect(play_se.bind(sound))
			# クリック時は統一して「決定音」(sound_click) 
			# もしクリック時も音階を鳴らしたい場合は bind(sound_hover) のままにします
			if !btn.pressed.is_connected(play_se):
				btn.pressed.connect(play_se.bind(sound_click))

# 音を再生する共通関数
# ★修正: 安全な再生関数
func play_se(stream_data):
	# ノード自体がシーンツリーにいない（画面切り替え中など）場合は再生処理をスキップしてエラーを防ぐ
	if not is_inside_tree():
		return
		
	if se_player and stream_data:
		# 念のためPlayerノードもツリーにいるか確認
		if se_player.is_inside_tree():
			se_player.stream = stream_data
			se_player.play()

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
	# 　1. 削除モードがONの場合の処理
	if delete_mode_button.button_pressed:
		# データが存在するか確認（データがないボタンを押しても何も起きないようにする）
		var data = Global.get_slot_info(slot_id)
		if data.is_empty():
			return # データがないなら削除処理もしない
			
		# 削除対象のスロットIDを記録
		pending_delete_slot_id = slot_id
		
		# 確認ダイアログを画面中央に表示
		delete_confirm_dialog.popup_centered()
	# 　 2. 通常（ロード）モードの場合の処理
	else:
		if Global.load_game(slot_id):
			print("スロット", slot_id, "をロードしてゲームを開始します")
			get_tree().change_scene_to_file("res://main_game.tscn")
		else:
			print("ロードに失敗しました")

#  ダイアログで「削除（OK）」が押されたときに実行される関数
func _on_delete_confirmed():
	if pending_delete_slot_id != -1:
		# Globalの削除関数を呼ぶ
		Global.delete_save(pending_delete_slot_id)
		
		# 画面の表示を更新（「データなし」にするため）
		update_load_slots_display()
		
		# 変数をリセット
		pending_delete_slot_id = -1

#  削除モードボタンを切り替えたときの見た目更新
func _on_delete_mode_toggled(_toggled_on):
	update_load_slots_display()



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
	# 現在、削除モードかどうか取得
	var is_delete_mode = delete_mode_button.button_pressed
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
			
			# 見た目の調整: データなしなら通常色
			btn.modulate = Color(1, 1, 1, 1)
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
			# 見た目の調整: 削除モード中はボタンを赤っぽくして警告する
			if is_delete_mode:
				btn.modulate = Color(1, 0.5, 0.5, 1) # 赤みがかった色
				btn.text = "[削除] " + btn.text # テキストにも[削除]とつける
			else:
				btn.modulate = Color(1, 1, 1, 1) # 通常色（白）

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


func _on_delet_mode_button_pressed() -> void:
	pass # Replace with function body.
