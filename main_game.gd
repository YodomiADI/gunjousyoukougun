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

# --- 3. 初期化処理 ---
func _ready():
	message_window.message_finished.connect(_on_message_window_finished)
	
	if Global.is_loading_process:
		_restore_visuals_from_save()
		Global.is_loading_process = false 
	
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
		se_player.stream = ev.se
		se_player.play()

	Global.add_to_backlog(ev.character_name, ev.text)
	%CharacterContainer.update_portraits(ev)
	if ev.shake_screen: apply_shake()

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
func show_choices(choices: Array):
	for child in choice_container.get_children(): child.queue_free()
	for i in range(choices.size()):
		var btn = Button.new()
		btn.text = choices[i]
		btn.custom_minimum_size = Vector2(200, 50)
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
