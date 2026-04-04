# main_game.gd
extends Control

# --- 1. ノード参照 ---
@onready var background = %Foreground
@onready var bgm_player = $BGMPlayer
@onready var se_player = $SEPlayer
@onready var kokorone_timer_label = $KokoroneTimerLabel
@onready var choice_container = $ChoiceContainer
@onready var message_window = %Panel 
@onready var director = $GameDirector 

@onready var backlog_canvas = $BacklogCanvas
@onready var log_list = $BacklogCanvas/Panel/ScrollContainer/LogList

# --- 2. システム変数 ---
var is_auto: bool = false
var is_skipping: bool = false
@export var auto_wait_time: float = 1.5

@onready var auto_button = $SystemButtons/AutoButton
@onready var skip_button = $SystemButtons/SkipButton

@onready var pause_menu = $PauseMenu 
@onready var menu_button = $SystemButtons/MenuButton # 追加したボタン

var day7_resist_button: Button = null

var is_waiting_for_hover: bool = false # ホバー待ち状態のフラグ
var hover_target_id: String = ""       # 待っている対象のキャラID
var active_choice_labels: Array = []   # 選択肢の死期更新用

# チュートリアル用のメッセージラベルを動的に作る（シーンに直接配置してもOKです）
var tutorial_label: Label

# --- 3. 初期化処理 ---
func _ready():
	
	# チュートリアルラベルの作成
	tutorial_label = Label.new()
	tutorial_label.text = "対象にマウスを重ねて、死期を視てみよう"
	tutorial_label.add_theme_font_size_override("font_size", 30)
	tutorial_label.add_theme_color_override("font_color", Color.CYAN)
	tutorial_label.hide()
	# 画面中央付近に配置
	tutorial_label.position = Vector2(300, 300) 
	add_child(tutorial_label)
	message_window.message_finished.connect(_on_message_window_finished)
	# --- 2. 初期化処理 ---
	if Global.is_loading_process:
		_restore_visuals_from_save()
		Global.is_loading_process = false 
	# --- 3. 最後にシナリオを開始する ---
	# これを呼ぶと render_event が動くので、必ず一番最後に書く
	director.start_scenario(Global.current_chapter_id)
	
func _restore_visuals_from_save():
	if Global.current_bg_path != "":
		background.texture = load(Global.current_bg_path)
	if Global.current_bgm_path != "":
		bgm_player.stream = load(Global.current_bgm_path)
		bgm_player.play()

# --- 4. 演出の実行（監督から命令される） ---
func render_event(ev: DialogueEvent):
	if ev.background:
		background.texture = ev.background
		Global.current_bg_path = ev.background.resource_path
	if ev.bgm and bgm_player.stream != ev.bgm:
		bgm_player.stream = ev.bgm
		bgm_player.play()
		Global.current_bgm_path = ev.bgm.resource_path
	if ev.se:
		print("SE再生を試みます: ", ev.se.resource_path) # これが出力されるか？
		se_player.stream = ev.se
		se_player.play()

	Global.add_to_backlog(ev.character_name, ev.text)
	%CharacterContainer.update_portraits(ev)
	if ev.shake_screen: apply_shake()
	
	if ev.require_hover_tutorial and ev.target_char_id != "":
		# ホバー待ち状態に突入
		is_waiting_for_hover = true
		hover_target_id = ev.target_char_id
		tutorial_label.show()
	else:
		is_waiting_for_hover = false
		tutorial_label.hide()

	# 選択肢があるかチェック
	if ev.choices.size() > 0:
		show_choices(ev.choices, [], ev.target_char_id) # 引数を追加
	
	if is_skipping:
		message_window.display_message(ev.character_name, ev.text)
		message_window.skip_typing()
		get_tree().create_timer(0.05).timeout.connect(advance_line)
	else:
		message_window.display_message(ev.character_name, ev.text)

# --- 5. 進行管理と入力 ---
func advance_line():
	if choice_container.visible: return
	director.next_line()

func _unhandled_input(event):
	# カウンター（プロキシ）を触っている間は、一切の入力を無視する
	if Global.is_hovering_proxy:
		return
		
	# UI（バックログや選択肢）が出ている時は入力を受け付けない
	if (backlog_canvas and backlog_canvas.visible) or choice_container.visible:
		return

	# A. ショートカットキーの処理
	if event.is_action_pressed("ui_auto"): 
		toggle_auto()
		return
	if event.is_action_pressed("ui_skip"): 
		toggle_skip()
		return
	
	# B. クリックまたは決定キーの処理（★ここを整理しました）
	var is_left_click = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	var is_accept_key = event.is_action_pressed("ui_accept")

	if is_left_click or is_accept_key:
		# ホバー待機中ならクリック進行をブロックして無視する
		if is_waiting_for_hover:
			return
		
		# オートやスキップ中なら停止するだけ
		if is_auto or is_skipping:
			stop_modes()
			return 
		
		# MessageWindowの文字表示状態によって挙動を変える
		# skip_typing() が true を返した＝「文字をパッと出した」ので、ここでは終了
		# skip_typing() が false を返した＝「すでに文字は出ていた」ので、次へ進む
		if not message_window.skip_typing():
			advance_line()
			
			

# --- 6. システムボタンの接続用関数（復活！） ---

func _on_auto_button_pressed():
	toggle_auto()

func _on_skip_button_pressed():
	toggle_skip()

func _on_backlog_button_pressed():
	_update_backlog_view()
	backlog_canvas.show()

func _on_backlog_close_button_pressed():
	backlog_canvas.hide()

# --- 7. UI内部処理 ---

func _update_backlog_view():
	for child in log_list.get_children(): child.queue_free()
	for entry in Global.backlog:
		var log_item = Label.new()
		log_item.text = "%s\n%s\n" % [entry["name"] if entry["name"] != "" else "（名前なし）", entry["text"]]
		log_item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		log_list.add_child(log_item)

func toggle_auto():
	is_auto = !is_auto
	is_skipping = false 
	_update_button_visuals()
	if is_auto and !message_window.is_typing: advance_line()

func toggle_skip():
	is_skipping = !is_skipping
	is_auto = false 
	_update_button_visuals()
	if is_skipping: advance_line()

func stop_modes():
	is_auto = false; is_skipping = false
	_update_button_visuals()

func _on_message_window_finished():
	if is_auto:
		get_tree().create_timer(auto_wait_time).timeout.connect(func():
			if is_auto: advance_line()
		)

func _update_button_visuals():
	auto_button.modulate = Color.CYAN if is_auto else Color.WHITE
	skip_button.modulate = Color.ORANGE if is_skipping else Color.WHITE

# --- 8. 選択肢・特殊演出 ---
func show_choices(choices: Array, disabled_indices: Array = [], target_id: String = ""):
	day7_resist_button = null 
	active_choice_labels.clear() # リセット
	hover_target_id = target_id  # _processで更新するために保存
	
	for child in choice_container.get_children(): child.queue_free()
	
	for i in range(choices.size()):
		var btn = Button.new()
		btn.text = choices[i]
		btn.custom_minimum_size = Vector2(400, 80) # 死期を表示するため少し大きめに
		
		# --- 対象キャラが指定されていれば、右下に死期ラベルを追加 ---
		if target_id != "" and Global.death_data.has(target_id):
			var time_label = Label.new()
			# 初期テキスト
			time_label.text = "死期: " + Global.format_death_time(Global.get_current_death_time(target_id))
			time_label.add_theme_font_size_override("font_size", 16)
			time_label.add_theme_color_override("font_color", Color.WHITE)
			# 右下にアンカーを設定
			time_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			time_label.position = Vector2(-10, -30) # 少し内側にずらす
			
			btn.add_child(time_label)
			active_choice_labels.append(time_label) # リアルタイム更新用リストに追加
			
		# ---「運命に抗う」ボタンを後で監視するために変数に入れておく---
		if choices[i].contains("運命に抗う"):
			day7_resist_button = btn
		
		# --- 無効化の判定 ---
		if i in disabled_indices:
			btn.disabled = true # ボタンをグレーアウトして押せなくする
			btn.focus_mode = Control.FOCUS_NONE # 選択もできないようにする
		
		btn.pressed.connect(_on_choice_selected.bind(i))
		choice_container.add_child(btn)
	
	choice_container.show()

func _on_choice_selected(index: int):
	choice_container.hide()
	director.handle_choice(index)

func apply_shake():
	var tween = create_tween()
	var start_pos = position
	tween.tween_property(self, "position", start_pos + Vector2(10, 0), 0.05)
	tween.tween_property(self, "position", start_pos - Vector2(10, 0), 0.05)
	tween.tween_property(self, "position", start_pos, 0.05)

func _on_location_pressed(location_id: String):
	director.handle_location_selected(location_id)


func _on_menu_button_pressed() -> void:
	# Escキーを押したときと同じ関数を呼び出すだけ！
	# メニューを開く前に、オートやスキップが動いていたら止めてあげるのが親切！
	stop_modes() 
	
	# ポーズメニュー内の toggle_pause を実行
	pause_menu.toggle_pause()
	
# --- _process 関数を追加（または既存のものに追記） ---
func _process(_delta):
	# 監視中のボタンがあり、かつまだ無効化されていない場合
	if day7_resist_button and not day7_resist_button.disabled:
		# リアルタイムで死期をチェック
		if Global.get_current_death_time("Kokorone") <= 0:
			day7_resist_button.disabled = true
			day7_resist_button.focus_mode = Control.FOCUS_NONE
			# ついでにタイマーをここで止めてもいいかもしれません
			Global.is_timer_active = false
			print("時間切れにより選択肢が封鎖されました")
	# ★ホバー待ちチュートリアルの監視
	if is_waiting_for_hover and hover_target_id != "":
		# Globalのデータで、対象キャラが「発見済み(discovered)」になったらクリア！
		if Global.death_data.has(hover_target_id) and Global.death_data[hover_target_id]["discovered"]:
			is_waiting_for_hover = false
			tutorial_label.hide()
			# 0.5秒くらい余韻を残してから自動で次の行へ進む
			get_tree().create_timer(0.5).timeout.connect(advance_line)
			
	# ★選択肢ボタンの死期リアルタイム更新
	if active_choice_labels.size() > 0 and hover_target_id != "":
		var current_time = Global.get_current_death_time(hover_target_id)
		var time_str = Global.format_death_time(current_time)
		for label in active_choice_labels:
			if is_instance_valid(label):
				label.text = "死期: " + time_str
