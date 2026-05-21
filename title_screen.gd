# title_screen.gd
extends Control

# --- UIノードへの参照 ---
@onready var main_menu = $MainMenu
@onready var load_menu = $LoadMenu
@onready var chapter_select_menu = $ChapterSelectMenu

# 第2部・チャプターセレクトボタン
@onready var part2_button = $MainMenu/Part2Button
@onready var chapter_select_button = $MainMenu/ChapterSelectButton

# 確認ダイアログと削除モードボタン
@onready var delete_confirm_dialog = $DeletConfirmDialog
@onready var confirmation_dialog = $ConfirmationDialog # 全初期化用
@onready var delete_mode_button = $LoadMenu/VBoxContainer/DeletModeButton

# 設定画面・オーディオ設定画面
@onready var settings_canvas = $SettingCanvas
@onready var config_menu = $ConfigMenu # ルート直下にあるConfigMenuを指定

# 効果音用のプレイヤーを取得
@onready var se_player = $SEPlayer

# --- 効果音アセットのロード ---
var sound_si = preload("res://SE/シ.mp3") 
var scale_sounds = [
	preload("res://SE/ド.mp3"), # AutoSaveButton用
	preload("res://SE/レ.mp3"), # Slot1Button用
	preload("res://SE/ミ.mp3"), # Slot2Button用
	preload("res://SE/ファ.mp3"), # Slot3Button用
	preload("res://SE/ソ.mp3")  # BackButton用
]
var sound_click = preload("res://SE/時計の針マウスオーバー.mp3")

# --- ロード用ボタンの配列 ---
@onready var load_slot_buttons = [
	$LoadMenu/VBoxContainer/AutoSaveButton, # Slot 0 (Auto Save)
	$LoadMenu/VBoxContainer/Slot1Button,     # Slot 1
	$LoadMenu/VBoxContainer/Slot2Button,     # Slot 2
	$LoadMenu/VBoxContainer/Slot3Button      # Slot 3
]
@onready var load_back_button = $LoadMenu/VBoxContainer/BackButton

# 削除一時保存用
var pending_delete_slot_id: int = -1

func _ready():
	get_tree().paused = false
	
	# 1. システムデータを読み込んで最新状態にする
	Global.load_system_data()
	
	# 2. 第1部クリアフラグの状態を取得してボタンを制御
	var is_cleared = Global.system_data.get("is_part1_cleared", false)
	print("第1部クリア状況: ", is_cleared)
	
	part2_button.visible = true
	chapter_select_button.visible = true
	part2_button.disabled = !is_cleared
	chapter_select_button.disabled = !is_cleared
	
	if not is_cleared:
		part2_button.text = "??? (第1部クリアで解放)"
		chapter_select_button.text = "Locked"
	else:
		part2_button.text = "第2部：日々の章"
		chapter_select_button.text = "チャプターセレクト"
		
	# 3. 画面の初期状態をセット
	main_menu.visible = true
	load_menu.visible = false
	chapter_select_menu.visible = false
	
	# 4. 各種ボタン・ダイアログのシグナル接続
	_setup_signals()
	
	# 5. チャプターセレクト・効果音のセットアップ
	setup_chapter_buttons()
	setup_sound_effects()

# --- 内部的なシグナル接続処理 ---
func _setup_signals():
	# ロードスロットボタンの接続
	for i in range(load_slot_buttons.size()):
		var btn = load_slot_buttons[i]
		if !btn.pressed.is_connected(_on_slot_button_pressed):
			btn.pressed.connect(_on_slot_button_pressed.bind(i))
			
	# セーブ削除確認ダイアログの接続（※インデントのバグを修正）
	if delete_confirm_dialog:
		if !delete_confirm_dialog.confirmed.is_connected(_on_delete_confirmed):
			delete_confirm_dialog.confirmed.connect(_on_delete_confirmed)
	else:
		print("警告: DeleteConfirmDialogが見つかりません。")
		
	# 全データ初期化ダイアログの接続
	if confirmation_dialog:
		if !confirmation_dialog.confirmed.is_connected(_on_confirmation_dialog_confirmed):
			confirmation_dialog.confirmed.connect(_on_confirmation_dialog_confirmed)
	else:
		print("警告: ConfirmationDialogが見つかりません。")

# --- 効果音（SE）のセットアップ ---
func setup_sound_effects():
	# メインメニューボタン -> 「シ」の音
	var title_buttons = [
		$MainMenu/StartButton,
		$MainMenu/LoadButton, 
		$MainMenu/QuitButton
	]
	for btn in title_buttons:
		if btn:
			if !btn.mouse_entered.is_connected(play_se):
				btn.mouse_entered.connect(play_se.bind(sound_si))
			if !btn.pressed.is_connected(play_se):
				btn.pressed.connect(play_se.bind(sound_click))

	# ロードメニューのボタン -> 「ドレミファソ」
	var scale_buttons = load_slot_buttons + [load_back_button]
	for i in range(scale_buttons.size()):
		if i < scale_sounds.size():
			var btn = scale_buttons[i]
			var sound = scale_sounds[i]
			if btn:
				if !btn.mouse_entered.is_connected(play_se):
					btn.mouse_entered.connect(play_se.bind(sound))
				if !btn.pressed.is_connected(play_se):
					btn.pressed.connect(play_se.bind(sound_click))

# 音を再生する共通関数
func play_se(stream_data):
	if not is_inside_tree(): return
	if se_player and stream_data:
		if se_player.is_inside_tree():
			se_player.stream = stream_data
			se_player.play()

# --- ボタン処理（メインメニュー） ---

# 「はじめから」
func _on_start_button_pressed():
	Global.reset_game_progress()
	get_tree().change_scene_to_file("res://main_game.tscn")

# 「つづきから」
func _on_load_menu_button_pressed():
	switch_to_load_menu()

# 「終了」
func _on_quit_button_pressed():
	get_tree().quit()

# 第2部開始ボタン
func _on_part2_button_pressed():
	get_tree().change_scene_to_file("res://main_game2.tscn")

# --- ボタン処理（チャプターセレクト画面） ---

func _on_chapter_select_button_pressed():
	main_menu.visible = false
	chapter_select_menu.visible = true

func _on_chapter_back_button_pressed():
	chapter_select_menu.visible = false
	main_menu.visible = true
	
func setup_chapter_buttons():
	var chapter_map = {
		"prologue": get_node_or_null("ChapterSelectMenu/VBoxContainer/GridContainer/Btn_Prologue"),
		"day_1":    get_node_or_null("ChapterSelectMenu/VBoxContainer/GridContainer/Btn_Day1"),
		"day_2":    get_node_or_null("ChapterSelectMenu/VBoxContainer/GridContainer/Btn_Day2"),
		"day_3":    get_node_or_null("ChapterSelectMenu/VBoxContainer/GridContainer/Btn_Day3"),
		"day_4":    get_node_or_null("ChapterSelectMenu/VBoxContainer/GridContainer/GridContainer/Btn_Day4"), # 階層ミス防止に get_node_or_null を使用
		"day_5":    get_node_or_null("ChapterSelectMenu/VBoxContainer/GridContainer/Btn_Day5"),
		"day_6":    get_node_or_null("ChapterSelectMenu/VBoxContainer/GridContainer/Btn_Day6"),
		"day_7":    get_node_or_null("ChapterSelectMenu/VBoxContainer/GridContainer/Btn_Day7")
	}
	
	for chapter_id in chapter_map.keys():
		var btn = chapter_map[chapter_id]
		if btn:
			if btn.pressed.is_connected(_start_chapter):
				btn.pressed.disconnect(_start_chapter)
			btn.pressed.connect(_start_chapter.bind(chapter_id))

func _start_chapter(chapter_id_to_start):
	Global.reset_game_progress() 
	Global.current_chapter_id = chapter_id_to_start
	print("チャプター選択から開始: ", chapter_id_to_start)
	get_tree().change_scene_to_file("res://main_game.tscn")

# --- ボタン処理（ロードメニュー） ---

func _on_slot_button_pressed(slot_id):
	# 削除モードがONの場合
	if delete_mode_button.button_pressed:
		var data = Global.get_slot_info(slot_id)
		if data.is_empty(): return 
		
		pending_delete_slot_id = slot_id
		delete_confirm_dialog.popup_centered()
	# 通常ロードモードの場合
	else:
		if Global.load_game(slot_id):
			print("スロット", slot_id, "をロードしました")
		else:
			print("ロードに失敗しました")

func _on_delete_confirmed():
	if pending_delete_slot_id != -1:
		Global.delete_save(pending_delete_slot_id)
		update_load_slots_display()
		pending_delete_slot_id = -1

func _on_delete_mode_toggled(_toggled_on):
	update_load_slots_display()

func _on_back_button_pressed():
	switch_to_main_menu()

# --- 画面切り替え・表示更新ロジック ---

func switch_to_main_menu():
	main_menu.visible = true
	load_menu.visible = false

func switch_to_load_menu():
	main_menu.visible = false
	load_menu.visible = true
	update_load_slots_display()

func update_load_slots_display():
	var is_delete_mode = delete_mode_button.button_pressed
	for i in range(load_slot_buttons.size()):
		var slot_id = i 
		var btn = load_slot_buttons[i]
		if not btn: continue
		
		var data = Global.get_slot_info(slot_id)
		
		if data.is_empty():
			if slot_id == 0:
				btn.text = "オートセーブ : -- データなし --"
			else:
				btn.text = "スロット %d : -- データなし --" % slot_id
			btn.disabled = true
			btn.modulate = Color(1, 1, 1, 1)
		else:
			var ch_name = Global.chapter_names.get(data["chapter_id"], data["chapter_id"])
			var time_str = Global.format_time(data.get("play_time", 0))
			
			if slot_id == 0:
				btn.text = "オートセーブ : %s / %s" % [ch_name, time_str]
			else:
				btn.text = "スロット %d : %s / %s" % [slot_id, ch_name, time_str]
			
			btn.disabled = false
			if is_delete_mode:
				btn.modulate = Color(1, 0.5, 0.5, 1) 
				btn.text = "[削除] " + btn.text 
			else:
				btn.modulate = Color(1, 1, 1, 1)

# --- 設定（セッティング）画面関連 ---

# 設定画面を開く
func _on_setting_button_pressed():
	play_se(sound_click)
	if settings_canvas:
		settings_canvas.visible = true 
		main_menu.visible = false     
	else:
		print("エラー: SettingCanvasが見つかりません")
		
# 音量設定を開く (ConfigMenu)
func _on_config_open_button_pressed():
	play_se(sound_click)
	if settings_canvas:
		settings_canvas.visible = false 
	if config_menu:
		config_menu.show()         

# 音量設定 (ConfigMenu) から戻る
func _on_config_menu_closed():
	if settings_canvas:
		settings_canvas.visible = true
	
# 「初期化」ボタン（確認ダイアログ表示）
func _on_init_button_pressed():
	play_se(sound_click)
	if confirmation_dialog:
		confirmation_dialog.dialog_text = "すべてのセーブデータと進行状況を消去します。\nよろしいですか？"
		confirmation_dialog.popup_centered()
	else:
		print("エラー: ConfirmationDialogが見つかりません")

# 全初期化の確定（OK押下時）
func _on_confirmation_dialog_confirmed():
	print("全データの初期化を実行します...")
	Global.initialize_all_data()
	get_tree().reload_current_scene()

# 設定画面を閉じてメインへ戻る
func _on_setting_back_button_pressed():
	play_se(sound_click)
	if settings_canvas:
		settings_canvas.visible = false 
		main_menu.visible = true
