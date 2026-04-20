# GameDirector.gd
extends Node

# メインゲーム（舞台装置）への参照
@onready var stage = get_parent()

var current_data: ScenarioData
var current_index: int = 0

var is_changing_scene: bool = false # 二重処理防止フラグ
# --- 1. シナリオ開始 ---
func start_scenario(id: String):
	# 1. データのロード
	current_data = Global.get_scenario_resource(id)
	if current_data == null:
		printerr("シナリオが見らつかりません: ", id)
		return
	
	# ★追加: Global側の現在IDも更新しておく（セーブ時などに重要）
	Global.current_chapter_id = id
	
	# 2. 下限値の更新
	Global.current_death_floor = current_data.chapter_death_floor
	
	# 3. インデックスのリセット
	# 新しくシナリオを始める時は常に 0 から。
	# ただし、ロード直後だけは Global の値を引き継ぎたいので条件分岐させます。
	if Global.is_loading_process:
		current_index = Global.current_line_index
		# ロード処理が終わったらフラグを下ろす（Global.gd側でやっていれば不要）
		# Global.is_loading_process = false 
	else:
		current_index = 0
		Global.current_line_index = 0 # Global側もリセット
	
	# 4. 章ごとの特殊ロジック
	_setup_chapter_logic(id)
	
	# 5. 再生開始
	play_current_event()

# 章ごとの特殊なロジック設定
func _setup_chapter_logic(id: String):
	# プロローグかどうかに関わらず、タイマーの計算自体は動かす
	Global.is_death_timer_active = true
	
	if id != "prologue":
		Global.current_death_floor = Global.player_death_seconds - Global.SECONDS_PER_DAY
		
	if id == "day_7":
		Global.is_timer_active = true
		
		# --- 追加：ココロネの関連タイマー変数を全て239秒（約4分）に同期する ---
		Global.kokorone_death_seconds = 20.0
		Global.death_timers["Kokorone"] = 20.0
		
		# UI表示用の新しいデータ構造の方も上書きする（これが画面に反映される）
		if Global.death_data.has("Kokorone"):
			Global.death_data["Kokorone"]["red"] = 20.0

# --- 2. 進行管理 ---
func play_current_event():
	# すでにシーン切り替え中なら何もしない
	if is_changing_scene: return
	
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

# 選択肢が選ばれた時
func handle_choice(index: int):
	# 現在のイベントデータを取得（変数名はそちらの環境に合わせてください）
	var current_event = current_data.events[current_index]
	
	# 1. 選んだ選択肢による死期の増減を適用（プレイヤー対象の場合）
	# ※target_char_idに適用するようにも作れますが、一旦メインの寿命と仮定
	if current_event.choice_time_modifiers.size() > index:
		var mod = current_event.choice_time_modifiers[index]
		if mod != 0.0:
			# マイナスの値が設定されていれば寿命が減る
			Global.player_death_seconds += mod 
			# 下限を下回らないようにする
			Global.player_death_seconds = max(Global.current_death_floor, Global.player_death_seconds)

	# 2. 分岐先が指定されていれば、そのシナリオIDへジャンプ！
	if current_event.choice_next_scenario_ids.size() > index:
		var next_id = current_event.choice_next_scenario_ids[index]
		if next_id != "":
			print("シナリオ分岐: ", next_id, " へジャンプします")
			start_scenario(next_id)
			return # ジャンプしたのでここで終了
			
	# 3. 分岐先がない（空文字）場合は、単純に合流して次の行へ
	next_line()
# マップで場所を選んだ時の処理
func handle_location_selected(_location_id: String):
	Global.advance_all_timers(Global.SECONDS_PER_PERIOD)
	# 必要ならここで特定のシナリオへ飛ばす判定を書く
	# get_tree().change_scene_to_file(...)

# --- 4. 章終了のロジック（ここが一番重要！） ---
func _finish_chapter():
	if is_changing_scene: return
	# 報酬とフラグの処理（元のコードから完全移植）
	Global.add_flag(current_data.reward_flag)
	
	match current_data.reward_type:
		"Heart": Global.heart_count += 1
		"Flame": Global.flame_count += 1
		"Soul": Global.soul_count += 1
	
	# "day_7" の終わりはまだ選択肢（続き）があるので、1日経過の処理を除外する
	if not Global.is_part2 and current_data.chapter_id != "prologue" and current_data.chapter_id != "day_7":
		Global.advance_all_timers(Global.SECONDS_PER_DAY)
		
	# 次の行動の判定
	match current_data.next_action:
		ScenarioData.NextAction.AUTO_NEXT:
			Global.current_chapter_id = current_data.next_chapter_id
			Global.current_line_index = 0
			# 安全のため call_deferred で実行
			get_tree().call_deferred("reload_current_scene")
			
		ScenarioData.NextAction.DETERMINE_END:
			if Global.current_chapter_id == "day_7":
				
				# ココロネの red (歪み死期) の現在値を取得
				# ※ Global.get_current_death_time は、red/whiteのうち
				#   その時表示されている（または優先される）方を返す想定です。
				var current_red_time = Global.get_current_death_time("Kokorone")
				
				var choice_texts = ["運命に抗う（通常エンドへ）", "諦める（バッドエンドへ）"]
				var disabled_list = []
				
				# redの数値が0以下なら、0番目のボタン（運命に抗う）を無効化リストに入れる
				if current_red_time <= 0:
					disabled_list.append(0)
				
				# 拡張した show_choices を呼び出す
				stage.show_choices(choice_texts, disabled_list)
				
			
		ScenarioData.NextAction.OPEN_MAP:
			get_tree().change_scene_to_file("res://map_selection.tscn")
			
		ScenarioData.NextAction.GO_TO_TITLE:
			if Global.current_chapter_id == "bad_end1":
				# バッドエンド1からのリトライ処理
				Global.current_chapter_id = "day_7"
