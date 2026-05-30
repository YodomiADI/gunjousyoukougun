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
		printerr("シナリオが見つかりません: ", id)
		return
	
	#  Global側の現在IDも更新しておく（セーブ時などに重要）
	# ファイル名ではなく、.tresファイル内に設定したChapter IDを正とする
	Global.current_chapter_id = current_data.chapter_id
	
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

	# 6. セットアップが終わったので、ロード中フラグを確実に下ろす
	Global.is_loading_process = false

# 章ごとの特殊なロジック設定
func _setup_chapter_logic(_id: String):
	# 基本的にどの章でも計算は動かす
	Global.is_death_timer_active = true
	
	var chapter = current_data.chapter_id
	
	# プロローグ以外なら、その日の「死の下限値」を設定する
	if chapter != "prologue":
		# 今のプレイヤーの残り秒数から24時間分を引いた場所が、この章の限界
		Global.current_death_floor = Global.player_death_seconds - Global.SECONDS_PER_DAY
		
	# Day 7（審判）の特殊演出
	if chapter == "day_7":
		Global.kokorone_death_seconds = 20.0
		if Global.death_data.has("Kokorone"):
			Global.death_data["Kokorone"]["red"] = 20.0
			
# --- 2. 進行管理 ---
func play_current_event():
	# データがない、または切り替え中なら即座に帰る
	if current_data == null or is_changing_scene: 
		return
	
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
	is_changing_scene = true # 二重処理防止
	# 報酬とフラグの処理（元のコードから完全移植）
	Global.add_flag(current_data.reward_flag)
	
	match current_data.reward_type:
		"Heart": Global.heart_count += 1
		"Flame": Global.flame_count += 1
		"Soul": Global.soul_count += 1
	
	# "day_7" の終わりはまだ選択肢（続き）があるので、1日経過の処理を除外する
	if not Global.is_part2 and current_data.chapter_id != "prologue" and current_data.chapter_id != "day_7":
		Global.advance_all_timers(Global.SECONDS_PER_DAY)
		
	# シーン遷移の前に水彩フェードインで画面を覆う
	# await で完全に塗りつぶされるまで待ってからシーンを切り替える
	await stage.fade_in_for_scene_change(0.6)
	
	# 次の行動の判定
	match current_data.next_action:
		ScenarioData.NextAction.AUTO_NEXT:
			Global.current_chapter_id = current_data.next_chapter_id
			Global.current_line_index = 0
			# 安全のため call_deferred で実行
			# reload_current_scene はフレーム末尾に実行されるため
			# call_deferred で安全にキューイングする
			get_tree().call_deferred("reload_current_scene")
			
		ScenarioData.NextAction.OPEN_MAP:
			get_tree().change_scene_to_file("res://map_selection.tscn")
			
		ScenarioData.NextAction.GO_TO_TITLE:
			# ★バッドエンド等からタイトルへ戻る処理
			# 次に「つづきから」を選んだ時のためにIDだけ設定しておく
			# バッドエンド1なら次はDay7から、という設定なら変数はそのままでOK
			if Global.current_chapter_id == "bad_end1":
				Global.current_chapter_id = "day_7"
			
			# ★実際にタイトルシーンへ切り替える（パスは実際の環境に合わせてください）
			get_tree().change_scene_to_file("res://title_screen.tscn")

		# --- デバッグ用：ハッピーエンド（または特定の章）が終わったらタイトルへ ---
		ScenarioData.NextAction.DETERMINE_END:
			# --- ★ハッピーエンド・真エンド後の処理 ---
			# chapter_id が "true_end" や "happy_end" ならタイトルへ
			var c_id = current_data.chapter_id
			if c_id == "true_end" or c_id == "happy_end":
				print("エンディング到達。タイトルへ戻ります。")
				get_tree().change_scene_to_file("res://title_screen.tscn")
			else:
				# それ以外（Day 7の末尾など）でここに来た場合
				# 基本的にDay 7の分岐は .tres の「最後のイベント」に
				# 選択肢を持たせる設計にしたので、ここは予備の安全装置にします。
				print("チャプター終了: 次のアクションが未定義です。")
				get_tree().change_scene_to_file("res://title_screen.tscn")
