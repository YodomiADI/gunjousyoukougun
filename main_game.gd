# main_game.gd
extends Control

# --- 1. ノード参照 ---
@onready var background = %Foreground
@onready var bgm_player = $BGMPlayer
@onready var se_player = $SEPlayer

@onready var choice_container = %ChoiceContainer
@onready var message_window = %Panel 
@onready var director = $GameDirector 

@onready var backlog_canvas = $BacklogCanvas
@onready var log_list = $BacklogCanvas/Panel/ScrollContainer/LogList

@onready var fade_overlay = $TransitionLayer/FadeOverLay

# --- 2. システム変数 ---
var is_auto: bool = false
var is_skipping: bool = false
@export var auto_wait_time: float = 1.5

@onready var auto_button = %AutoButton
@onready var skip_button = %SkipButton

@onready var pause_menu = $PauseMenu 
@onready var menu_button = %MenuButton # 追加したボタン

var is_waiting_for_hover: bool = false # ホバー待ち状態のフラグ
var hover_target_id: String = ""       # 待っている対象のキャラID
# active_choice_labels を単なるラベル配列から、辞書の配列に変更して詳細なデータを保持させます
var active_choice_data: Array[Dictionary] = []

# トランジション実行中フラグ（二重起動・誤クリック防止）
var is_transitioning: bool = false

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
	# 章移行後フラグの確認と二重トランジション防止
	# start_scenario() より前にフラグを読んで is_transitioning を立てておく。
	# こうすることで、start_scenario() 内から呼ばれる render_event() が
	# bg_transition=AUTO のトランジションを自動スキップし、二重にならない。
	var coming_from_chapter_change = Global.start_with_transition
	if coming_from_chapter_change:
		Global.start_with_transition = false
		is_transitioning = true  # render_event のAUTO判定をブロック
		# オーバーレイを「塗りつぶし済み」状態でセットしておく
		var mat := fade_overlay.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("progress", 1.0)
		fade_overlay.show()
	# これを呼ぶと render_event が動くので、必ず一番最後に書く
	# シナリオ開始（render_event が呼ばれる。is_transitioning=true なら AUTO はスキップ）
	director.start_scenario(Global.current_chapter_id)
	

func _restore_visuals_from_save():
	if Global.current_bg_path != "":
		background.texture = load(Global.current_bg_path)
	if Global.current_bgm_path != "":
		bgm_player.stream = load(Global.current_bgm_path)
		bgm_player.play()

# ==============================================================
# トランジション関数群
# ==============================================================

## フェードアウト共通処理
## transition_do と _apply_background（章移行直後）の両方で使う
func _fade_out_overlay(duration: float = 0.6) -> void:
	# タメ：テクスチャ反映の1フレーム遅れを吸収する
	await get_tree().create_timer(0.08).timeout
 
	if not fade_overlay:
		is_transitioning = false
		return
 
	var mat := fade_overlay.material as ShaderMaterial
	if mat:
		var tween = create_tween()
		tween.tween_property(mat, "shader_parameter/progress", 1.0, duration)
		await tween.finished
 
	fade_overlay.hide()
	is_transitioning = false
 
 
## 背景切り替え用：水彩で覆う → callback実行 → _fade_out_overlay()
## render_event() → _apply_background() から await で呼ばれる
func transition_do(callback: Callable, duration: float = 1.0) -> void:
	if not fade_overlay:
		callback.call()
		return
 
	var mat := fade_overlay.material as ShaderMaterial
	if not mat:
		callback.call()
		return
 
	is_transitioning = true
	fade_overlay.show()
 
	# フェードイン（水彩が画面を塗りつぶす）
	var tween = create_tween()
	tween.tween_property(mat, "shader_parameter/progress", 0.0, duration * 0.45)
	await tween.finished
 
	# 完全に隠れた瞬間に背景を差し替える
	callback.call()
 
	# フェードアウト（共通処理）
	await _fade_out_overlay(duration * 0.45)
 
 
## 章移行用（フェードインのみ）：画面を水彩で覆い、シーン遷移を渡す
## GameDirector._finish_chapter() から await で呼ばれる
## フェードアウトは新シーンの _apply_background() が担当する
func fade_in_for_scene_change(duration: float = 0.6) -> void:
	if not fade_overlay: return
 
	var mat := fade_overlay.material as ShaderMaterial
	if not mat: return
 
	is_transitioning = true
	fade_overlay.show()
 
	var tween = create_tween()
	tween.tween_property(mat, "shader_parameter/progress", 0.0, duration)
	await tween.finished
 
	# 次のシーンに「覆われた状態から始まる」ことを伝える
	Global.start_with_transition = true
 
# ==============================================================
# 背景トランジションの振り分けロジック（render_event から呼ぶ）
# ==============================================================
 
## ev.bg_transition の設定に従って背景を切り替える。
## 章移行直後（is_transitioning=true）は fade-out のみ担当する。
## 戻り値なし。await で呼ぶこと。
func _apply_background(ev: DialogueEvent) -> void:
	# 背景指定がない場合でも、章移行直後ならフェードアウトだけ担当する
	if not ev.background:
		if is_transitioning:
			await _fade_out_overlay(0.6)
		return
 
	var do_change = func():
		background.texture = ev.background
		Global.current_bg_path = ev.background.resource_path
 
	match ev.bg_transition:
 
		DialogueEvent.BgTransition.NONE:
			# トランジションなし：即差し替え
			# 章移行直後でもフェードアウトは行わない（即見せる）
			do_change.call()
			if is_transitioning:
				# 覆われたままなのでフェードアウトだけする
				await _fade_out_overlay(0.6)
 
		DialogueEvent.BgTransition.WATERCOLOR:
			if is_transitioning:
				# 章移行直後：すでに覆われているので bg変更 → フェードアウトのみ
				do_change.call()
				await _fade_out_overlay(0.6)
			else:
				# 通常：フェードイン → bg変更 → フェードアウト
				await transition_do(do_change, 1.0)
 
		DialogueEvent.BgTransition.AUTO, _:
			if is_transitioning:
				# 章移行直後：すでに覆われているので bg変更 → フェードアウトのみ
				do_change.call()
				await _fade_out_overlay(0.6)
			elif ev.background != background.texture:
				# 通常：背景が変わるときだけトランジション
				await transition_do(do_change, 1.0)
			else:
				# 同じ背景：何もしない
				do_change.call()
 

func _check_button_disabled(ev: DialogueEvent, index: int) -> bool:
	if ev.disable_target_chars.size() <= index: return false
	
	var t_char = ev.disable_target_chars[index]
	var t_type = ev.disable_time_types[index]
	var threshold = ev.disable_thresholds[index]
	
	if t_char != "" and t_type > 0 and Global.death_data.has(t_char):
		# 指定されたタイプ（白か赤か）の現在の値を取得
		var current_val = Global.death_data[t_char]["white"] if t_type == 1 else Global.death_data[t_char]["red"]
		# 赤がまだ未観測（-1）の場合は白の値を基準にする
		if t_type == 2 and current_val == -1.0: current_val = Global.death_data[t_char]["white"]
		
		# 閾値を下回っていたら True（無効）を返す
		return current_val <= threshold
	return false

# --- 4. 演出の実行（監督から命令される） ---
func render_event(ev: DialogueEvent):
	# BGM・SEは背景トランジション前に先行して変える
	# （音は視覚より早く変わることで、場面転換の予感を演出できる）
	if ev.bgm and bgm_player.stream != ev.bgm:
		bgm_player.stream = ev.bgm
		bgm_player.play()
		Global.current_bgm_path = ev.bgm.resource_path
 
	if ev.se:
		se_player.stream = ev.se
		se_player.play()
	
	# 背景の切り替え（BgTransition設定に従って振り分け）
	await _apply_background(ev)
	
	# バックログ・立ち絵更新・画面揺れ
	Global.add_to_backlog(ev.character_name, ev.text)
	%CharacterContainer.update_portraits(ev)
	if ev.shake_screen: apply_shake()
	
	# ホバーチュートリアルの判定
	if ev.require_hover_tutorial and ev.target_char_id != "":
		is_waiting_for_hover = true
		hover_target_id = ev.target_char_id
		tutorial_label.show()
	else:
		is_waiting_for_hover = false
		tutorial_label.hide()

	# 選択肢があるかチェック
	if ev.choices.size() > 0:
		# 第3引数にターゲットIDを渡すことで、選択肢に死期が出るようになる
		show_choices(ev.choices, [], ev.target_char_id)
	
	# テキスト表示
	message_window.display_message(ev.character_name, ev.text)
	
	# スキップ中の処理（0.05秒で次へ）
	if is_skipping:
		message_window.skip_typing()
		get_tree().create_timer(0.05).timeout.connect(advance_line)


# --- 5. 進行管理と入力 ---
func advance_line():
	# 選択肢が出ている時や、ホバー待ちの時は勝手に進ませない
	# トランジション中も進行をブロックする
	if choice_container.visible or is_waiting_for_hover or is_transitioning:
		return
	director.next_line()

func _unhandled_input(event):
	# A. 入力を無視するケース
	if Global.is_hovering_proxy: return # タイマーを触っている
	if backlog_canvas and backlog_canvas.visible: return # 履歴を見ている
	if choice_container.visible: return # 選択肢を選んでいる
	if is_waiting_for_hover: return # チュートリアル中
	if is_transitioning: return # トランジション中はクリック・キー入力を無視する
	
	# B. システム操作
	if event.is_action_pressed("ui_auto"): 
		toggle_auto()
		return
	if event.is_action_pressed("ui_skip"): 
		toggle_skip()
		return
	
	# C. クリックまたは決定キーでの進行
	var is_confirm = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or event.is_action_pressed("ui_accept")

	if is_confirm:
		# オートやスキップ中なら解除して止める
		if is_auto or is_skipping:
			stop_modes()
			return 
		
		# 文字表示中ならパッと全表示、表示済みなら次へ
		if not message_window.skip_typing():
			advance_line()

# --- 6. システムボタンの接続用関数 ---

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
	# リストを一度空にする
	for child in log_list.get_children(): child.queue_free()
	
	# Globalの履歴データを元にラベルを作成
	for entry in Global.backlog:
		var log_item = Label.new()
		var char_name = entry["name"] if entry["name"] != "" else "（名前なし）"
		log_item.text = "%s\n%s\n" % [char_name, entry["text"]]
		log_item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		log_list.add_child(log_item)

func toggle_auto():
	# 選択肢が出ている時はオートを開始させない
	if not is_auto and choice_container.visible: return
	
	is_auto = !is_auto
	is_skipping = false 
	_update_button_visuals()
	
	# オート開始時に文字が表示終わっていたら次へ
	if is_auto and not message_window.is_typing: 
		advance_line()

func toggle_skip():
	# 選択肢が出ている時はスキップを開始させない
	if not is_skipping and choice_container.visible: return
	
	is_skipping = !is_skipping
	is_auto = false 
	_update_button_visuals()
	
	if is_skipping: 
		advance_line()

func stop_modes():
	is_auto = false
	is_skipping = false
	_update_button_visuals()

func _on_message_window_finished():
	# メッセージが終わった後のオート進行処理
	if is_auto:
		# 選択肢やチュートリアル待ちなら、ここでオートを一度止める（安全策）
		if choice_container.visible or is_waiting_for_hover:
			stop_modes()
			return

		get_tree().create_timer(auto_wait_time).timeout.connect(func():
			# タイマー待機中に状態が変わっている可能性があるので再チェック
			if is_auto and not choice_container.visible and not is_waiting_for_hover:
				advance_line()
		)

func _update_button_visuals():
	# ボタンの色で現在のモードをわかりやすく
	auto_button.modulate = Color.CYAN if is_auto else Color.WHITE
	skip_button.modulate = Color.ORANGE if is_skipping else Color.WHITE
	
# --- 8. 選択肢・特殊演出 ---
func show_choices(choices: Array, disabled_indices: Array = [], target_id: String = ""):
	active_choice_data.clear() # リセット
	hover_target_id = target_id  # _processで更新するために保存
	
	# 現在実行中のイベントを取得
	var current_event = director.current_data.events[director.current_index]
	
	# 既存の選択肢をクリア
	for child in choice_container.get_children(): child.queue_free()
	
	for i in range(choices.size()):
		var btn = Button.new()
		btn.text = choices[i]
		btn.custom_minimum_size = Vector2(400, 80) # 死期を表示するため少し大きめに
		
		# --- 対象キャラが指定されていれば、右下に死期ラベルを追加 ---
		if target_id != "" and Global.death_data.has(target_id):
			var time_label = Label.new()
			time_label.text = "死期: " + Global.format_death_time(Global.get_current_death_time(target_id))
			time_label.add_theme_font_size_override("font_size", 16)
			time_label.add_theme_color_override("font_color", Color.WHITE)
			time_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			time_label.position = Vector2(-10, -30) # 少し内側にずらす
			btn.add_child(time_label)
			
			# 配列から増減値と表示タイプを取得
			var modifier = current_event.choice_time_modifiers[i] if current_event.choice_time_modifiers.size() > i else 0.0
			var display_type = current_event.choice_time_display_types[i] if current_event.choice_time_display_types.size() > i else 0
				
			active_choice_data.append({
				"label": time_label,
				"modifier": modifier,
				"display_type": display_type
			})
			
		# --- データ駆動の無効化判定（事前に用意した共通関数を呼び出すだけ！） ---
		var is_disabled = disabled_indices.has(i)
		if not is_disabled and current_event != null:
			is_disabled = _check_button_disabled(current_event, i)

		# 判定結果をボタンに適用
		btn.disabled = is_disabled
		btn.pressed.connect(_on_choice_selected.bind(i))
		choice_container.add_child(btn)
	
	choice_container.show()

func _on_choice_selected(index: int):
	choice_container.hide()
	active_choice_data.clear() # 選択完了したのでデータをクリア
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
	stop_modes() 
	pause_menu.toggle_pause()
	

# --- 9. 毎フレームの更新処理 ---
func _process(_delta):
	# A. ホバー待ちチュートリアルの監視
	if is_waiting_for_hover and hover_target_id != "":
		# 安全な実在チェックを挟みつつ、発見されたか判定
		if Global.death_data.has(hover_target_id) and Global.death_data[hover_target_id].get("discovered", false):
			is_waiting_for_hover = false
			tutorial_label.hide()
			# 余韻を残して自動で次の行へ
			get_tree().create_timer(0.5).timeout.connect(advance_line)
			
	# B. 選択肢ボタンのリアルタイム更新（表示中のみ実行）
	if choice_container.visible and active_choice_data.size() > 0 and hover_target_id != "":
		var current_event = director.current_data.events[director.current_index]
		var buttons = choice_container.get_children()
		
		for i in range(active_choice_data.size()):
			var data = active_choice_data[i]
			if not is_instance_valid(data["label"]): continue
			
			# 1. 基準となる時間を決定
			var base_time = 0.0
			if data["display_type"] == 1: # White強制
				base_time = Global.death_data[hover_target_id]["white"]
			elif data["display_type"] == 2: # Red強制
				base_time = Global.death_data[hover_target_id]["red"]
				if base_time == -1.0: base_time = Global.death_data[hover_target_id]["white"]
			else: # Auto (デフォルト)
				base_time = Global.get_current_death_time(hover_target_id)
			
			# 2. 増減予測の計算
			var predicted_time = base_time + data["modifier"]
			if hover_target_id == "Player":
				predicted_time = max(Global.current_death_floor, predicted_time)
			else:
				predicted_time = max(0.0, predicted_time)

			# 3. テキストの構築
			var time_str = Global.format_death_time(base_time)
			if data["modifier"] != 0.0:
				var predicted_str = Global.format_death_time(predicted_time)
				data["label"].text = "死期: %s\n ⇒ %s" % [time_str, predicted_str]
			else:
				data["label"].text = "死期: " + time_str

			# 4. Display Type に基づいてラベルの色を変える
			match data["display_type"]:
				1: data["label"].add_theme_color_override("font_color", Color.CYAN) # 鮮やかな水色
				2: data["label"].add_theme_color_override("font_color", Color(1, 0.3, 0.3)) # 警告の赤
				_: data["label"].add_theme_color_override("font_color", Color.WHITE) # 通常の白

			# 5. リアルタイム無効化監視（ここも共通関数でスッキリ！）
			if i < buttons.size():
				var btn = buttons[i] as Button
				# まだ有効なボタンが、リアルタイムで寿命が尽きて閾値を下回ったら無効化する
				if btn and not btn.disabled and _check_button_disabled(current_event, i):
					btn.disabled = true
					btn.focus_mode = Control.FOCUS_NONE
					print(hover_target_id, " の時間切れにより選択肢 ", i, " をリアルタイム無効化しました")
