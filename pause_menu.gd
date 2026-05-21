# pause_menu.gd
extends CanvasLayer

# タイトル画面のファイルパス
const TITLE_SCENE_PATH = "res://title_screen.tscn"

# --- 1. ノード参照 ---
@onready var main_buttons_container = $Control/Panel/MainButtons
@onready var save_slots_menu = $Control/Panel/SaveSlotsMenu
@onready var config_menu = $Control/Panel/ConfigMenu
@onready var death_memo = $Control/Panel/DeathMemoUi
@onready var death_timer_label = $Control/Panel/DeathTimerLabel

# スロットボタンの配列
@onready var slot_buttons = [
	$Control/Panel/SaveSlotsMenu/Slot1_Button,
	$Control/Panel/SaveSlotsMenu/Slot2_Button,
	$Control/Panel/SaveSlotsMenu/Slot3_Button
]

# SEPlayerと音源
@onready var se_player = $SEPlayer
var sound_hover = preload("res://SE/時計の針マウスオーバー.mp3")
var sound_click = preload("res://SE/シ.mp3")


# --- 2. 初期化処理 ---
func _ready():
	visible = false
	main_buttons_container.visible = true
	save_slots_menu.visible = false
	config_menu.hide()
	
	# シグナル接続
	config_menu.menu_closed.connect(_on_config_menu_closed)
	death_memo.closed.connect(_on_death_memo_closed)
	
	# セーブスロットの自動接続
	for i in range(slot_buttons.size()):
		var btn = slot_buttons[i]
		if !btn.pressed.is_connected(_on_save_slot_pressed):
			btn.pressed.connect(_on_save_slot_pressed.bind(i + 1))
			
	setup_pause_sound_effects()


# --- 3. 音声・共通演出 ---
func setup_pause_sound_effects():
	# コンフィグボタンなども含めて、音を鳴らすボタンをリストアップ
	var all_buttons = [
		$Control/Panel/MainButtons/go_back_game_Button,
		$Control/Panel/MainButtons/ToSaveMenuButton,
		$Control/Panel/MainButtons/go_to_title_Button,
		$Control/Panel/MainButtons/DeathMemoButton,
		$Control/Panel/MainButtons/ConfigButton, # リストに追加
		$Control/Panel/SaveSlotsMenu/BackButton
	] + slot_buttons
	
	for btn in all_buttons:
		if btn == null: continue
		if !btn.mouse_entered.is_connected(play_se):
			btn.mouse_entered.connect(play_se.bind(sound_hover))
		if !btn.pressed.is_connected(play_se):
			btn.pressed.connect(play_se.bind(sound_click))

func play_se(stream_data):
	if not is_inside_tree(): return
	if se_player and stream_data:
		se_player.stream = stream_data
		se_player.play()


# --- 4. 進行・ポーズ制御 ---
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

func toggle_pause():
	var tree = get_tree()
	tree.paused = !tree.paused
	visible = tree.paused

	if visible:
		switch_to_main_menu()

func _process(_delta):
	# ポーズ画面が開いている間だけ、プレイヤーの死期タイマーをリアルタイム更新
	if visible:
		# ★新システムに合わせて、Globalから安全にプレイヤーの現在の死期を取得
		var p_time = Global.get_current_death_time("Player")
		death_timer_label.text = "あなたの死期まで\n" + Global.format_death_time(p_time)
		
		# 残り7日（604800秒）を切ったら文字を警告の赤にする
		if p_time < 604800.0:
			death_timer_label.modulate = Color.RED
		else:
			death_timer_label.modulate = Color.WHITE


# --- 5. メニュー画面の切り替え ---
func switch_to_main_menu():
	main_buttons_container.visible = true
	save_slots_menu.visible = false
	config_menu.hide()
	# 手記はオープン関数側で管理されるため、ここでは閉じられた状態にする
	
func switch_to_save_menu():
	main_buttons_container.visible = false
	save_slots_menu.visible = true
	update_save_slots_display()

func update_save_slots_display():
	for i in range(slot_buttons.size()):
		var slot_id = i + 1
		var btn = slot_buttons[i]
		var data = Global.get_slot_info(slot_id)
		
		if data.is_empty():
			btn.text = "スロット %d : ---- データなし ----" % slot_id
		else:
			var ch_name = Global.chapter_names.get(data["chapter_id"], data["chapter_id"])
			var time_str = Global.format_time(data.get("play_time", 0))
			btn.text = "スロット %d : %s / %s" % [slot_id, ch_name, time_str]


# --- 6. 各種ボタン・UIシグナル処理 ---

# ゲームに戻る
func _on_go_back_game_button_pressed() -> void:
	toggle_pause()

# タイトルへ
func _on_go_to_title_button_pressed() -> void:
	toggle_pause() 
	get_tree().change_scene_to_file(TITLE_SCENE_PATH)

# セーブメニューへ開く・戻る
func _on_to_save_menu_button_pressed():
	switch_to_save_menu()

func _on_back_button_pressed():
	switch_to_main_menu()

# セーブ実行
func _on_save_slot_pressed(slot_id):
	Global.save_game(slot_id)
	update_save_slots_display()
	print("スロット %d にセーブしました" % slot_id)

# コンフィグ画面
func _on_config_button_pressed():
	# 音は setup_pause_sound_effects で自動再生されるため、ここの再生処理は削除してクリーンに
	config_menu.show()
	main_buttons_container.visible = false

func _on_config_menu_closed():
	switch_to_main_menu()

# 手記画面
func _on_death_memo_button_pressed():
	main_buttons_container.visible = false
	death_memo.open_memo()

func _on_death_memo_closed():
	switch_to_main_menu()
