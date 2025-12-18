extends Control

@onready var name_label = $Panel/NameBox/NameLabel # パスは自分の構成に合わせてください
@onready var char_sprite = $CharacterSprite
# TextureRectを取得
@onready var background_rect = $Background
# BGMプレイヤーを取得
@onready var bgm_player = $BGMPlayer

@onready var text_label = $Panel/Label
# 「FadeOverlay」を取得
# もしPanelの中に作ってしまった場合は $Panel/FadeOverlay になりますが、
# 基本的にはControl直下（$FadeOverlay）にある想定です。
@onready var fade_overlay = $FadeOverLay


# 現在読み込んでいるシナリオデータ
var current_scenario_data: ScenarioData
var dialogue_list: Array[DialogueEvent] = []
var current_index = 0
# アニメーションを管理するための変数
var current_tween: Tween

# アニメーション中に入力を受け付けないようにするためのフラグ
var is_transitioning = false

func _ready():
	# 初期化：フェード用の幕を透明にしておく
	if fade_overlay:
		fade_overlay.color.a = 0.0
	
#   # ロード処理を削除
	# タイトル画面で「つづきから」が選ばれた場合にのみGlobal.load_game()が実行されます
	# 「はじめから」が選ばれた場合はGlobal変数がリセットされた状態で遷移してきます
	
	# ★Globalから現在の章のテキストを取得してセットする
	setup_current_chapter()
	# Globalの現在の状態（行番号）を適用
	current_index = Global.current_line_index
	# もしセーブデータの続きが、もう文章がない場所（クリア後など）だったら
	if current_index >= dialogue_list.size():
		current_index = 0 # 最初に戻すか、クリア画面へ飛ばす処理などを入れる
	update_text()

# 章のデータをセットする関数
func setup_current_chapter():
	var chapter_id = Global.current_chapter_id
# Globalからリソースを取得
	current_scenario_data = Global.get_scenario_data(chapter_id)

	if current_scenario_data:
		# リソース内のデータを取り出す
		dialogue_list = current_scenario_data.events
		# ※初期背景・BGMは、最初のイベント(0番目)で設定するようにすればOK
	else:
		# エラー処理用
		pass


func _input(event):
	# 画面切り替え中なら、クリックしても反応させない
	if is_transitioning:
		return
	
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		
		# 文字がまだ全部表示されていなかったら（スキップ）
		if text_label.visible_ratio < 1.0:
			if current_tween:
				current_tween.kill()
			text_label.visible_ratio = 1.0
			
		# 文字が全部表示されているなら、次の文章へ
		else:
			current_index += 1
			
			# 現在の行数を更新
			Global.current_line_index = current_index
			
			if current_index < dialogue_list.size():
				# まだこの章のテキストがある場合
				# ここで1回だけセーブすればOKです
				Global.save_game()
				update_text()
			else:
				# 章の終わり！
				# ここではセーブせず、次の章へ遷移する処理に任せます
				# (go_to_next_chapter -> change_chapter 内でセーブされるため)
				go_to_next_chapter()
# 次の章へ進む処理
func go_to_next_chapter():
	# Day7の場合、ここで分岐処理を入れる
	if Global.current_chapter_id == "day_7":
		show_route_selection() # 選択肢ボタンを表示する関数（後述）を作る
		return

	# 現在のデータの「次の章ID」を確認
	if current_scenario_data and current_scenario_data.next_chapter_id != "":
		play_chapter_transition(current_scenario_data.next_chapter_id)
	
	# 第1部終了フラグが立っている場合
	elif current_scenario_data and current_scenario_data.is_end_of_part1:
		finish_part1()

	else:
		# 次がない場合はとりあえずタイトルへ
		get_tree().change_scene_to_file("res://title_screen.tscn")

# 第1部クリア処理
func finish_part1():
# ★ここを変更：システムデータに「クリアした」と書き込む
	Global.complete_part1()
	
	# 第2部のメインゲームシーンへ移動
	# 演出を入れるならここにフェード処理など
	get_tree().change_scene_to_file("res://main_game2.tscn")

# 分岐ボタンを表示する（簡易例）
func show_route_selection():
	# 本来は専用のUIパネルを用意して .show() するのが良いです
	# ここではコードでボタンを生成する例を書きます
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(400, 300) # 画面中央あたり
	add_child(vbox)
	
	var btn_happy = Button.new()
	btn_happy.text = "希望を見出す (Happy Route)"
	btn_happy.pressed.connect(func(): 
		vbox.queue_free()
		play_chapter_transition("happy_end")
	)
	vbox.add_child(btn_happy)
	
	var btn_bad = Button.new()
	btn_bad.text = "運命を受け入れる (Bad Route)"
	btn_bad.pressed.connect(func(): 
		vbox.queue_free()
		play_chapter_transition("bad_end")
	)
	vbox.add_child(btn_bad)


# フェードアウト → 章切り替え → フェードイン を行う関数
func play_chapter_transition(next_chapter_id):
	# 1. 操作ロック
	is_transitioning = true
	
	# 2. フェードアウト（画面を徐々に黒くする）
	var tween = create_tween()
	# colorのアルファ値を0(透明)から1(不透明)へ、1.5秒かけて変化させる
	tween.tween_property(fade_overlay, "color:a", 1.0, 1.5)
	
	# アニメーションが終わるのを待つ
	await tween.finished
	
	# 3. 画面が真っ暗な裏で、章データを切り替える
	change_chapter(next_chapter_id)
	
	# ちょっとだけ真っ暗な時間を維持する（余韻）
	await get_tree().create_timer(0.5).timeout
	
	# 4. フェードイン（画面を徐々に明るくする）
	var tween_in = create_tween()
	# colorのアルファ値を1(不透明)から0(透明)へ、1.5秒かけて変化させる
	tween_in.tween_property(fade_overlay, "color:a", 0.0, 1.5)
	
	await tween_in.finished
	
	# 5. 操作ロック解除
	is_transitioning = false


# 章を切り替えてリセットする共通関数
func change_chapter(next_chapter_id):
	# 1. Globalの変数を更新
	Global.current_chapter_id = next_chapter_id
	Global.current_line_index = 0 # 行数を0にリセット
	
	# 2. シナリオデータを再読み込み
	setup_current_chapter()
	current_index = 0
	
	# 3. オートセーブ（新しい章の頭でセーブしておく）
	Global.save_game()
	
	# 4. 画面更新
	update_text()

func update_text():
	# データの存在チェック
	if dialogue_list.is_empty():
		push_warning("シナリオデータが空です！")
		text_label.text = "（シナリオデータが登録されていません）"
		return

	# 現在のインデックスが配列の範囲内かチェック
	if current_index < 0 or current_index >= dialogue_list.size():
		return
	
	
	var current_event = dialogue_list[current_index]
	
	if current_event == null:
		return

	# --- 1. 立ち絵の更新 ---
	if current_event.character_sprite:
		char_sprite.texture = current_event.character_sprite
		char_sprite.show() # 画像があるなら表示
	else:
		# 画像が設定されていない場合、立ち絵を消すか前のままにするか選べます
		# 完全に消したい場合は：
		char_sprite.hide() 

	# --- 2. 名前欄の更新 ---
	if current_event.character_name != "":
		name_label.text = current_event.character_name
		name_label.show() # 名前があるなら表示
	else:
		name_label.hide() # 名前が空なら名前枠自体を隠す
	
	
	# --- 3. 演出の実行（背景・BGM・SE：これまでの処理） ---
	# 背景の変更
	if current_event.change_background:
		background_rect.texture = current_event.change_background
	
	# BGMの変更
	if current_event.change_bgm:
		if bgm_player.stream != current_event.change_bgm:
			bgm_player.stream = current_event.change_bgm
			bgm_player.play()
			
	# SEの再生
	if current_event.play_se:
		# ノードツリーに $SEPlayer があることを確認してください
		if has_node("SEPlayer"):
			$SEPlayer.stream = current_event.play_se
			$SEPlayer.play()

# --- 4. テキストの表示 ---
	text_label.text = current_event.text
	
	# アニメーション設定
	text_label.visible_ratio = 0.0
	var duration = text_label.get_total_character_count() * 0.05
	
	if current_tween:
		current_tween.kill()
	current_tween = create_tween()
	current_tween.tween_property(text_label, "visible_ratio", 1.0, duration)
