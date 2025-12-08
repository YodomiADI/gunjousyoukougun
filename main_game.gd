extends Control

# 背景画像のパス設定
# "res://..." の部分は、あなたが用意した実際の画像パスに書き換えてください
var background_images = {
	"prologue": preload("res://images/ステグラと星空.jpg"),
	"chapter_1": preload("res://images/田舎の線路沿いの道（夕方）.jpg")
}

# BGMのパス設定
# "res://..." の部分は用意した音楽ファイルのパスに書き換えてください
var bgm_list = {
	"prologue": preload("res://BGM/プロローグ.mp3"), # プロローグ用BGM
	"chapter_1": preload("res://BGM/プロローグ.mp3") # 第一章用BGM
}

# TextureRectを取得
@onready var background_rect = $Background

# BGMプレイヤーを取得
@onready var bgm_player = $BGMPlayer

# ここには直接書かず、空にしておきます
var dialogue_list = []
var current_index = 0
@onready var text_label = $Panel/Label

# 「FadeOverlay」を取得
# もしPanelの中に作ってしまった場合は $Panel/FadeOverlay になりますが、
# 基本的にはControl直下（$FadeOverlay）にある想定です。
@onready var fade_overlay = $FadeOverLay

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
	#背景を更新する
	update_background()
	
	# BGMも更新する
	update_bgm()
	
	# Globalの辞書からテキスト配列を取得
	if Global.scenarios.has(chapter_id):
		dialogue_list = Global.scenarios[chapter_id]
	else:
		print("エラー: 指定された章が見つかりません -> ", chapter_id)
		dialogue_list = ["エラー：テキストデータがありません"]

# 現在の章に合わせて背景画像をセットする関数 背景更新ロジック
func update_background():
	var chapter_id = Global.current_chapter_id
	if background_images.has(chapter_id):
		background_rect.texture = background_images[chapter_id]
	else:
		print("背景画像が設定されていません: ", chapter_id)
		# 必要ならデフォルト画像を設定するなど

# 現在の章に合わせてBGMを再生する関数
func update_bgm():
	var chapter_id = Global.current_chapter_id
	
	# 辞書にその章のBGMが登録されているか確認
	if bgm_list.has(chapter_id):
		var next_stream = bgm_list[chapter_id]
		
		# 「今流れている曲」と「次に流す曲」が違う場合のみ切り替える
		# (同じ章をロードした時などに最初から再生されるのを防ぐため)
		if bgm_player.stream != next_stream:
			bgm_player.stream = next_stream
			bgm_player.play()
	else:
		# 辞書にない場合は音楽を止める（無音のシーンなど）
		print("BGMが設定されていません: ", chapter_id)
		bgm_player.stop()


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
			
			# ページが進んだタイミングで、今の場所をGlobalに記録してセーブを実行する
			Global.current_line_index = current_index
			Global.save_game() 
			
			if current_index < dialogue_list.size():
				# まだこの章のテキストがある場合
				Global.current_line_index = current_index
				Global.save_game()
				update_text()
			else:
				# ★章の終わり！次の章へ遷移する処理
				go_to_next_chapter()

# 次の章へ進む処理
func go_to_next_chapter():
	print("章の終了判定: ", Global.current_chapter_id)
	
	if Global.current_chapter_id == "prologue":
		# プロローグが終わったら第一章へ
		# ★ここで直接 change_chapter を呼ばず、演出用の関数を呼びます
		play_chapter_transition("chapter_1")
		
	elif Global.current_chapter_id == "chapter_1":
		# 第一章が終わったら（例：タイトルへ戻る、第二章へ、など）
		print("第一章終了。タイトルへ戻ります")
		# get_tree().change_scene_to_file("res://title_screen.tscn")
		text_label.text = "（続く……）"

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
	text_label.text = dialogue_list[current_index]
	
	text_label.visible_ratio = 0.0
	var duration = text_label.text.length() * 0.05
	
	if current_tween:
		current_tween.kill()
	current_tween = create_tween()
	current_tween.tween_property(text_label, "visible_ratio", 1.0, duration)
