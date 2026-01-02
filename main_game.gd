# main_game.gd
extends Control

@onready var text_label = $Panel/Label
@onready var name_label = $Panel/NameBox/NameLabel
@onready var char_sprite = $CharacterSprite
@onready var background = $Background
@onready var bgm_player = $BGMPlayer
@onready var se_player = $SEPlayer
@onready var kokorone_timer_label = $KokoroneTimerLabel
@onready var choice_container = $ChoiceContainer
@export var typing_speed: float = 0.05 # 1文字出すのにかかる秒数
var typing_tween: Tween # 文字送り用のTween
@onready var next_icon = $Panel/NextIcon # ▼アイコン
@onready var animation_player = $AnimationPlayer # アニメーションプレイヤー

@onready var backlog_canvas = $BacklogCanvas
@onready var log_list = $BacklogCanvas/Panel/ScrollContainer/LogList

var is_auto: bool = false
var is_skipping: bool = false
@export var auto_wait_time: float = 1.5 # オート時の待機時間（秒）

@onready var auto_button = $SystemButtons/AutoButton
@onready var skip_button = $SystemButtons/SkipButton

@onready var left_slot = $CharacterContainer/LeftSlot
@onready var right_slot = $CharacterContainer/RightSlot
@onready var center_slot = $CharacterContainer/CenterSlot

var current_data: ScenarioData
var current_index: int = 0
var is_typing: bool = false

func _ready():
	# 初期状態では隠しておく
	next_icon.hide()
	# 1. まずデータをロードする
	load_scenario(Global.current_chapter_id)
	
	# 2. ロードに失敗した（current_dataが空）なら、ここで処理を中断する
	if current_data == null:
		return

	# プロローグの開始時制限
	if Global.current_chapter_id != "prologue":
		Global.prepare_death_timer_for_next_day()
	else:
		Global.current_death_floor = Global.player_death_seconds - Global.SECONDS_PER_DAY
	
	# DAY7のタイマー起動
	if Global.current_chapter_id == "day_7":
		start_day7()
	else:
		kokorone_timer_label.visible = false
		Global.is_timer_active = true
	
	current_index = Global.current_line_index
	display_event()

func _process(delta):
	if Global.is_timer_active:
		kokorone_timer_label.visible = true
		# 辞書から取得して表示（メインタイマーも辞書にまとめると管理が楽です）
		kokorone_timer_label.text = "ココロネの死期まで\n" + Global.format_death_time(Global.death_timers.get("Kokorone", 0.0))
		
		# 全キャラの時間を減らす
		for key in Global.death_timers.keys():
			Global.death_timers[key] -= delta
			
		# 各スロットの頭上タイマーを更新
		if left_slot.visible:
			left_slot.update_timer()
		if right_slot.visible:
			right_slot.update_timer()
		if center_slot.visible: 
			center_slot.update_timer() # 追加
	else:
		kokorone_timer_label.visible = false
		
func load_scenario(id: String):
	current_data = Global.get_scenario_resource(id)
	if not current_data:
		print("Error: Scenario not found: ", id)
		get_tree().change_scene_to_file("res://title_screen.tscn")



func _unhandled_input(event):
	# UI表示中は入力を無視
	if (backlog_canvas and backlog_canvas.visible) or (choice_container and choice_container.visible):
		return

	# キーボードショートカット
	if event.is_action_pressed("ui_auto"):
		toggle_auto()
	if event.is_action_pressed("ui_skip"):
		toggle_skip()

	# マウスクリックまたは決定キー
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed):
		# オート/スキップ中にクリックされたら、まずモードを解除する
		if is_auto or is_skipping:
			stop_modes()
			return # 解除だけして、テキストは進めない（誤操作防止）

		if is_typing:
			complete_typing() # タイピング中なら全表示
		else:
			advance_line() # 表示済みなら次の行へ

# モード解除用
func stop_modes():
	is_auto = false
	is_skipping = false
	_update_button_visuals() # 見た目を更新
	print("Auto/Skip stopped")

func toggle_auto():
	is_auto = !is_auto
	is_skipping = false # スキップとは排他
	_update_button_visuals() # 見た目を更新
	
	if is_auto and !is_typing:
		advance_line()

func toggle_skip():
	is_skipping = !is_skipping
	is_auto = false # オートとは排他
	_update_button_visuals() # 見た目を更新	
	
	if is_skipping:
		advance_line()



func advance_line():
	if current_data == null: return
	
	# ここでも念のためチェック（透明な壁対策）
	if choice_container and choice_container.visible:
		return
	# ここからが本来の「行を進める」処理
	current_index += 1
	if current_index < current_data.events.size():
		Global.current_line_index = current_index
		display_event()
	else:
		# シナリオの末尾に到達
		finish_chapter()
		
# --- ボタンの見た目（色）を変える処理 ---
func _update_button_visuals():
	# オートボタンの色
	if is_auto:
		auto_button.modulate = Color.CYAN # 起動中は水色に
	else:
		auto_button.modulate = Color.WHITE
		
	# スキップボタンの色
	if is_skipping:
		skip_button.modulate = Color.ORANGE # 起動中はオレンジに
	else:
		skip_button.modulate = Color.WHITE

# --- シグナル接続用の関数 ---

func _on_auto_button_pressed():
	toggle_auto()

func _on_skip_button_pressed():
	toggle_skip()

func display_event():
	# ここでNilチェックを入れることでクラッシュを防止
	if current_data == null or current_data.events.size() <= current_index:
		return


	var ev = current_data.events[current_index]

	if ev.background:
		background.texture = ev.background
		# Globalのバックログに保存
	Global.add_to_backlog(ev.character_name, ev.text)
	
	name_label.text = ev.character_name
	# 1. まず各スロットを更新 # 位置の指定に合わせてスロットを更新
	match ev.position:
		0: # NONE (全員消す)
			left_slot.hide()
			right_slot.hide()
			center_slot.hide()
		1: # LEFT
			left_slot.display(ev.character_name, ev.character_sprite, ev.char_id, ev.timer_offset, ev.character_scale, ev.base_scale)
			if ev.clear_other_slots: # ←ここがポイント！
				right_slot.hide()
				center_slot.hide()
		2: # RIGHT
			right_slot.display(ev.character_name, ev.character_sprite, ev.char_id, ev.timer_offset, ev.character_scale, ev.base_scale)
			if ev.clear_other_slots:
				left_slot.hide()
				center_slot.hide()
		3: # CENTER
			center_slot.display(ev.character_name, ev.character_sprite, ev.char_id, ev.timer_offset, ev.character_scale, ev.base_scale)
			if ev.clear_other_slots:
				left_slot.hide()
				right_slot.hide()
			
			
		# --- ここから「暗くする」演出の追加 ---
	
	# 現在のイベントの位置（1, 2, 3）を取得
	var current_pos = ev.position
	
	# 全スロットをリストにしてループで回す
	for slot in [left_slot, right_slot, center_slot]:
		if slot.visible:
			# このスロットの場所が、今の発言位置と同じなら「アクティブ」
			# 例: ev.position が 1 (LEFT) で、今処理してるのが left_slot なら true
			var is_speaker = false
			if slot == left_slot and current_pos == 1: is_speaker = true
			if slot == right_slot and current_pos == 2: is_speaker = true
			if slot == center_slot and current_pos == 3: is_speaker = true
			
			slot.set_focus(is_speaker)
			
# --- タイピング演出の開始 ---
	next_icon.hide() # 新しい行が始まったらアイコンを隠す
	animation_player.stop() # アニメーションも止める

	text_label.text = ev.text
# --- スキップモードの場合 ---
	if is_skipping:
		text_label.visible_characters = -1
		is_typing = false
		# 待機なしで即座に次へ行くための準備（少しだけ待たないと無限ループエラーになるため0.05秒程度待つ）
		get_tree().create_timer(0.05).timeout.connect(advance_line)
		return
	# --------------------------

	text_label.visible_characters = 0 # まず文字を隠す
	is_typing = true
	
	# 前のTweenが動いていたら止める
	if typing_tween:
		typing_tween.kill()
	
	# Tweenを使って文字数を 0 から 全文字数まで増やす
	typing_tween = create_tween()
	var duration = ev.text.length() * typing_speed
	typing_tween.tween_property(text_label, "visible_characters", ev.text.length(), duration)
	
	# 終わったら is_typing を false にする
	typing_tween.finished.connect(_on_typing_finished)
	# ---------------------------
	
	if ev.background:
		background.texture = ev.background
		
	if ev.bgm and bgm_player.stream != ev.bgm:
		bgm_player.stream = ev.bgm
		bgm_player.play()
		
	if ev.se:
		se_player.stream = ev.se
		se_player.play()
		
	if ev.shake_screen:
		apply_shake()

# --- 選択肢を表示する関数 ---
func show_choices(choices: Array):
	# すでに表示されているなら二重に作らない
	if choice_container.visible:
		return
	print("選択肢を表示します: ", choices)
	# 以前のボタンを削除して掃除
	for child in choice_container.get_children():
		child.queue_free()
	
	# 選択肢ボタンを動的に作成
	for i in range(choices.size()):
		var btn = Button.new()
		btn.text = choices[i]
		btn.custom_minimum_size = Vector2(200, 50) # ボタンのサイズ調整
		
		# マウスフィルターを明示的に「Stop」にする（クリックを受け取るため）
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		
		# 接続（重複接続を避けるために一回リセットするのが安全）
		if btn.pressed.is_connected(_on_choice_selected):
			btn.pressed.disconnect(_on_choice_selected)
		btn.pressed.connect(_on_choice_selected.bind(i))
		
		choice_container.add_child(btn)
		
	choice_container.show() # コンテナを表示
	# 他のUIよりも手前に表示する
	choice_container.move_to_front()
# --- 選択肢がクリックされた時の処理 ---
func _on_choice_selected(index: int):
	print("ボタンがクリックされました！ インデックス: ", index) # ← これが出るか確認
	choice_container.hide()
	
	# DAY7の特殊分岐例
	if Global.current_chapter_id == "day_7":
		if index == 0: # 1番目のボタン（通常エンドへ）
			Global.current_chapter_id = "happy_end1"
		else: # 2番目のボタン（バッドエンドへ）
			Global.current_chapter_id = "bad_end1"
	
	# 次の章へ移動
	print("次の章へ移動します: ", Global.current_chapter_id)
	Global.current_line_index = 0
	get_tree().reload_current_scene()

func finish_chapter():
	Global.add_flag(current_data.reward_flag)
	
	# カウントの加算
	match current_data.reward_type:
		"Heart": Global.heart_count += 1
		"Flame": Global.flame_count += 1
		"Soul": Global.soul_count += 1
	
	# 次のアクションの判定
	match current_data.next_action:
		# --- [重要] プロローグや通常章の移動はこれ ---
		ScenarioData.NextAction.AUTO_NEXT:
			Global.current_chapter_id = current_data.next_chapter_id
			Global.current_line_index = 0
			get_tree().reload_current_scene()
			
		# --- エンディングや分岐の判定 ---
		ScenarioData.NextAction.DETERMINE_END:
			if Global.current_chapter_id == "day_7":
				Global.is_timer_active = false # タイマー停止
				# ここで「選択肢」を出す
				if Global.kokorone_death_seconds > 0:
					# 3分59秒以内に読み終えた場合
					show_choices(["運命に抗う（通常エンドへ）", "諦める（バッドエンドへ）"])
				else:
					# タイムアップ（0秒以下）の場合
					show_choices(["……（手遅れだった、バッドエンドへ）"])
			else:
				# DAY7以外でDETERMINE_ENDが設定されている場合（第2部など）
				Global.current_chapter_id = Global.evaluate_part2_ending()
				Global.current_line_index = 0
				get_tree().reload_current_scene()
			
		# --- マップ画面へ ---
		ScenarioData.NextAction.OPEN_MAP:
			get_tree().change_scene_to_file("res://map_selection.tscn")
			
		# --- タイトルへ戻る / バッドエンドのリトライ ---
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

func apply_shake():
	var tween = create_tween()
	var start_pos = position
	tween.tween_property(self, "position", start_pos + Vector2(10, 0), 0.05)
	tween.tween_property(self, "position", start_pos - Vector2(10, 0), 0.05)
	tween.tween_property(self, "position", start_pos, 0.05)

# 一気に表示させる関数
func complete_typing():
	if typing_tween:
		typing_tween.kill()
	text_label.visible_characters = -1
	# 強制終了しても「文字表示完了」の処理を呼ぶ
	_on_typing_finished()
	
	# 文字表示が完了した時の共通処理 ---
func _on_typing_finished():
	is_typing = false
	next_icon.show() # アイコンを表示
	animation_player.play("wait") # 「▼点滅」アニメーションを再生
	
	# --- オートモードの場合 ---
	if is_auto:
		# 指定した秒数待ってから advance_line を呼ぶ
		get_tree().create_timer(auto_wait_time).timeout.connect(func():
			if is_auto: # 待っている間に解除されていないか確認
				advance_line()
		)
# --- バックログ画面を開く ---
func _on_backlog_button_pressed():
	# リストを一度掃除する
	for child in log_list.get_children():
		child.queue_free()
	
	# Globalのデータからラベルを生成して並べる
	for entry in Global.backlog:
		var log_item = Label.new()
		# 「名前: セリフ」の形式で表示
		var display_name = entry["name"] if entry["name"] != "" else "（名前なし）"
		log_item.text = "%s\n%s\n" % [display_name, entry["text"]]
		# 折り返し設定（ScrollContainer内で横にはみ出さないように）
		log_item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		log_list.add_child(log_item)
	
	backlog_canvas.show()

# --- バックログ画面を閉じる ---
func _on_backlog_close_button_pressed():
	backlog_canvas.hide()
