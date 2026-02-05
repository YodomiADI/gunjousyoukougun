# main_game.gd
extends Control

@onready var char_sprite = $CharacterSprite
@onready var background = $Background
@onready var bgm_player = $BGMPlayer
@onready var se_player = $SEPlayer
@onready var kokorone_timer_label = $KokoroneTimerLabel
@onready var choice_container = $ChoiceContainer

@onready var backlog_canvas = $BacklogCanvas
@onready var log_list = $BacklogCanvas/Panel/ScrollContainer/LogList

var is_auto: bool = false
var is_skipping: bool = false
@export var auto_wait_time: float = 1.5

@onready var auto_button = $SystemButtons/AutoButton
@onready var skip_button = $SystemButtons/SkipButton

# ★ここが重要：ManagerとWindowへの参照
@onready var message_window = %Panel

var current_data: ScenarioData
var current_index: int = 0
var current_bg_res_path: String = ""
var current_bgm_res_path: String = ""

func _ready():
	# ★ next_icon.hide() は削除しました
	
	load_scenario(Global.current_chapter_id)
	
	if current_data == null:
		return

	if Global.current_chapter_id != "prologue":
		Global.prepare_death_timer_for_next_day()
	else:
		Global.current_death_floor = Global.player_death_seconds - Global.SECONDS_PER_DAY
	
	if Global.current_chapter_id == "day_7":
		start_day7()
	else:
		kokorone_timer_label.visible = false
		Global.is_timer_active = true
	
	current_index = Global.current_line_index
	display_event()

	if Global.is_loading_process:
		if Global.current_bg_path != "":
			background.texture = load(Global.current_bg_path)
			current_bg_res_path = Global.current_bg_path
		if Global.current_bgm_path != "":
			bgm_player.stream = load(Global.current_bgm_path)
			bgm_player.play()
			current_bgm_res_path = Global.current_bgm_path
			
		Global.is_loading_process = false 
		
	# メッセージが終わった合図を受け取る
	message_window.message_finished.connect(_on_message_window_finished)

func _on_message_window_finished():
	if is_auto:
		get_tree().create_timer(auto_wait_time).timeout.connect(func():
			if is_auto:
				advance_line()
		)

func _process(_delta):
	pass

func load_scenario(id: String):
	current_data = Global.get_scenario_resource(id)
	if not current_data:
		print("Error: Scenario not found: ", id)
		get_tree().change_scene_to_file("res://title_screen.tscn")
	
	if id != "prologue":
		Global.is_death_timer_active = true
	else:
		Global.is_death_timer_active = false

func _unhandled_input(event):
	if (backlog_canvas and backlog_canvas.visible) or (choice_container and choice_container.visible):
		return

	if event.is_action_pressed("ui_auto"):
		toggle_auto()
	if event.is_action_pressed("ui_skip"):
		toggle_skip()

	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed):
		if is_auto or is_skipping:
			stop_modes()
			return 

		# ★ここを修正：ウィンドウに問い合わせる
		if not message_window.skip_typing():
			advance_line()

func stop_modes():
	is_auto = false
	is_skipping = false
	_update_button_visuals() 
	print("Auto/Skip stopped")

func toggle_auto():
	is_auto = !is_auto
	is_skipping = false 
	_update_button_visuals() 
	
	# ★ここを修正：ウィンドウの状態を見る
	if is_auto and !message_window.is_typing:
		advance_line()

func toggle_skip():
	is_skipping = !is_skipping
	is_auto = false 
	_update_button_visuals() 
	
	if is_skipping:
		advance_line()

func advance_line():
	if current_data == null: return
	
	if choice_container and choice_container.visible:
		return
	
	current_index += 1
	if current_index < current_data.events.size():
		Global.current_line_index = current_index
		display_event()
	else:
		finish_chapter()
		
func _update_button_visuals():
	if is_auto:
		auto_button.modulate = Color.CYAN 
	else:
		auto_button.modulate = Color.WHITE
		
	if is_skipping:
		skip_button.modulate = Color.ORANGE 
	else:
		skip_button.modulate = Color.WHITE

func _on_auto_button_pressed():
	toggle_auto()

func _on_skip_button_pressed():
	toggle_skip()

func display_event():
	if current_data == null or current_data.events.size() <= current_index:
		return

	var ev = current_data.events[current_index]

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
	
	# ★立ち絵処理（Managerに丸投げ）
	$CharacterContainer.update_portraits(ev)

	# ★メッセージ処理（Windowに丸投げ）
	if is_skipping:
		message_window.display_message(ev.character_name, ev.text)
		message_window.skip_typing()
		get_tree().create_timer(0.05).timeout.connect(advance_line)
	else:
		message_window.display_message(ev.character_name, ev.text)

	if ev.shake_screen:
		apply_shake()

func show_choices(choices: Array):
	if choice_container.visible:
		return
	print("選択肢を表示します: ", choices)
	for child in choice_container.get_children():
		child.queue_free()
	
	for i in range(choices.size()):
		var btn = Button.new()
		btn.text = choices[i]
		btn.custom_minimum_size = Vector2(200, 50) 
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		
		if btn.pressed.is_connected(_on_choice_selected):
			btn.pressed.disconnect(_on_choice_selected)
		btn.pressed.connect(_on_choice_selected.bind(i))
		
		choice_container.add_child(btn)
		
	choice_container.show() 
	choice_container.move_to_front()

func _on_choice_selected(index: int):
	print("ボタンがクリックされました！ インデックス: ", index)
	choice_container.hide()
	
	if Global.current_chapter_id == "day_7":
		if index == 0: 
			Global.current_chapter_id = "happy_end1"
		else: 
			Global.current_chapter_id = "bad_end1"
	
	print("次の章へ移動します: ", Global.current_chapter_id)
	Global.current_line_index = 0
	get_tree().reload_current_scene()

func finish_chapter():
	Global.add_flag(current_data.reward_flag)
	
	match current_data.reward_type:
		"Heart": Global.heart_count += 1
		"Flame": Global.flame_count += 1
		"Soul": Global.soul_count += 1
	
	if not Global.is_part2 and current_data.chapter_id != "prologue":
		Global.advance_all_timers(Global.SECONDS_PER_DAY)
		print("1日経過しました")
	
	match current_data.next_action:
		ScenarioData.NextAction.AUTO_NEXT:
			Global.current_chapter_id = current_data.next_chapter_id
			Global.current_line_index = 0
			get_tree().reload_current_scene()
			
		ScenarioData.NextAction.DETERMINE_END:
			if Global.current_chapter_id == "day_7":
				Global.is_timer_active = false 
				if Global.kokorone_death_seconds > 0:
					show_choices(["運命に抗う（通常エンドへ）", "諦める（バッドエンドへ）"])
				else:
					show_choices(["……（手遅れだった、バッドエンドへ）"])
			else:
				Global.current_chapter_id = Global.evaluate_part2_ending()
				Global.current_line_index = 0
				get_tree().reload_current_scene()
			
		ScenarioData.NextAction.OPEN_MAP:
			get_tree().change_scene_to_file("res://map_selection.tscn")
			
		ScenarioData.NextAction.GO_TO_TITLE:
			if Global.current_chapter_id == "bad_end1":
				Global.current_chapter_id = "day_7"
				Global.current_line_index = 0
				Global.kokorone_death_seconds = 239.0
				get_tree().reload_current_scene()
			else:
				get_tree().change_scene_to_file("res://title_screen.tscn")

func start_day7():
	Global.kokorone_death_seconds = 239.0
	Global.is_timer_active = true

func _on_location_pressed(_location_id: String):
	Global.advance_all_timers(Global.SECONDS_PER_PERIOD)
	if Global.pending_death_event != "":
		pass

func apply_shake():
	var tween = create_tween()
	var start_pos = position
	tween.tween_property(self, "position", start_pos + Vector2(10, 0), 0.05)
	tween.tween_property(self, "position", start_pos - Vector2(10, 0), 0.05)
	tween.tween_property(self, "position", start_pos, 0.05)

func _on_backlog_button_pressed():
	for child in log_list.get_children():
		child.queue_free()
	
	for entry in Global.backlog:
		var log_item = Label.new()
		var display_name = entry["name"] if entry["name"] != "" else "（名前なし）"
		log_item.text = "%s\n%s\n" % [display_name, entry["text"]]
		log_item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		log_list.add_child(log_item)
	
	backlog_canvas.show()

func _on_backlog_close_button_pressed():
	backlog_canvas.hide()
