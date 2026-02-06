# GameDirector.gd
extends Node

# メインゲーム（舞台装置）への参照
@onready var stage = get_parent()

var current_data: ScenarioData
var current_index: int = 0

# --- 1. シナリオ開始 ---
func start_scenario(id: String):
	current_data = Global.get_scenario_resource(id)
	if not current_data:
		printerr("シナリオが見つかりません: ", id)
		get_tree().change_scene_to_file("res://title_screen.tscn")
		return

	# 章ごとの初期設定（元の main_game の _ready からの引っ越し）
	_setup_chapter_logic(id)
	
	current_index = Global.current_line_index
	play_current_event()

# 章ごとの特殊なロジック設定
func _setup_chapter_logic(id: String):
	if id != "prologue":
		Global.prepare_death_timer_for_next_day()
		Global.is_death_timer_active = true
	else:
		Global.current_death_floor = Global.player_death_seconds - Global.SECONDS_PER_DAY
		Global.is_death_timer_active = false
	
	if id == "day_7":
		Global.kokorone_death_seconds = 239.0
		Global.is_timer_active = true

# --- 2. 進行管理 ---
func play_current_event():
	if current_index < current_data.events.size():
		Global.current_line_index = current_index
		var ev = current_data.events[current_index]
		stage.render_event(ev) 
	else:
		_finish_chapter()

func next_line():
	current_index += 1
	play_current_event()

# --- 3. 選択肢や場所の「判定」 ---

# プレイヤーが選択肢を選んだ時の処理（main_gameから呼ばれる）
func handle_choice(index: int):
	if Global.current_chapter_id == "day_7":
		if index == 0: 
			Global.current_chapter_id = "happy_end1"
		else: 
			Global.current_chapter_id = "bad_end1"
	
	Global.current_line_index = 0
	get_tree().reload_current_scene()

# マップで場所を選んだ時の処理
func handle_location_selected(_location_id: String):
	Global.advance_all_timers(Global.SECONDS_PER_PERIOD)
	# 必要ならここで特定のシナリオへ飛ばす判定を書く
	# get_tree().change_scene_to_file(...)

# --- 4. 章終了のロジック（ここが一番重要！） ---
func _finish_chapter():
	# 報酬とフラグの処理（元のコードから完全移植）
	Global.add_flag(current_data.reward_flag)
	
	match current_data.reward_type:
		"Heart": Global.heart_count += 1
		"Flame": Global.flame_count += 1
		"Soul": Global.soul_count += 1
	
	if not Global.is_part2 and current_data.chapter_id != "prologue":
		Global.advance_all_timers(Global.SECONDS_PER_DAY)

	# 次の行動の判定
	match current_data.next_action:
		ScenarioData.NextAction.AUTO_NEXT:
			Global.current_chapter_id = current_data.next_chapter_id
			Global.current_line_index = 0
			get_tree().reload_current_scene()
			
		ScenarioData.NextAction.DETERMINE_END:
			if Global.current_chapter_id == "day_7":
				Global.is_timer_active = false 
				if Global.kokorone_death_seconds > 0:
					stage.show_choices(["運命に抗う（通常エンドへ）", "諦める（バッドエンドへ）"])
				else:
					stage.show_choices(["……（手遅れだった、バッドエンドへ）"])
			else:
				# 第2部のエンディング判定
				Global.current_chapter_id = Global.evaluate_part2_ending()
				Global.current_line_index = 0
				get_tree().reload_current_scene()
			
		ScenarioData.NextAction.OPEN_MAP:
			get_tree().change_scene_to_file("res://map_selection.tscn")
			
		ScenarioData.NextAction.GO_TO_TITLE:
			if Global.current_chapter_id == "bad_end1":
				# バッドエンド1からのリトライ処理
				Global.current_chapter_id = "day_7"
