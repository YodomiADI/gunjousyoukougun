# MessageWindow.gd
extends Panel

# 完了をメインゲームに伝えるための「合図（シグナル）」
signal message_finished

@export var typing_speed: float = 0.05

# % を使って子ノードに直接アクセス
@onready var text_label = %Label
@onready var name_label = %NameLabel
@onready var next_icon = %NextIcon

var typing_tween: Tween
var icon_tween: Tween       # 次へアイコンの演出用
var is_typing: bool = false


func _ready():
	next_icon.hide()
	# 縦書き、横書きどちらでも馴染むように、アイコンの初期ピボット（中心点）を設定
	next_icon.pivot_offset = next_icon.size / 2


# メインゲームから「このセリフを出して！」と頼まれる関数
func display_message(char_name: String, full_text: String):
	# 進行中だった演出をすべてクリア
	_clear_tweens()
	
	# --- 名前欄のスマートな表示切り替え ---
	if char_name == "":
		name_label.text = ""
		# もし名前枠の背景ノード等があれば、ここで一緒に .hide() すると綺麗です
		name_label.hide() 
	else:
		name_label.text = char_name
		name_label.show()
		
	text_label.text = full_text
	text_label.visible_ratio = 0.0 # 最初は文字を隠す
	next_icon.hide()
	is_typing = true

	# 空テキスト（演出用のウェイトなど）へのセーフティ
	if full_text.length() == 0:
		_on_typing_finished()
		return

	# Tweenで文字をじわじわ出す演出
	typing_tween = create_tween()
	var duration = full_text.length() * typing_speed
	typing_tween.tween_property(text_label, "visible_ratio", 1.0, duration)
	
	# 終わったら完了処理へ
	typing_tween.finished.connect(_on_typing_finished)


# 文字が出終わった時の処理
func _on_typing_finished():
	is_typing = false
	text_label.visible_ratio = 1.0 # 念のため1.0を保証
	
	next_icon.show()
	_start_icon_animation() # 「次へ」アイコンをフワフワさせる
	
	# 最後にメインゲームへ通知（これによってタイミングバグを防ぐ）
	message_finished.emit()


# タイピング中にクリックされたら「一瞬で全表示」する関数
func skip_typing() -> bool:
	if is_typing:
		is_typing = false # 先にフラグを折って多重クリックを防ぐ
		if typing_tween:
			typing_tween.kill()
		
		# 出終わった時の処理を直接実行（全表示＋シグナル送信）
		_on_typing_finished()
		return true # スキップしたよ
	return false # タイピング中じゃなかったよ


# --- 内部演出用のヘルパー関数 ---

# 次へアイコンをフワフワ点滅させる（ノベルゲームらしさの演出）
func _start_icon_animation():
	if icon_tween: icon_tween.kill()
	
	next_icon.modulate.a = 1.0
	icon_tween = create_tween().set_loops() # 無限ループ
	
	# 0.6秒かけて少し透明になりつつ、下に4ピクセル動く
	icon_tween.tween_property(next_icon, "modulate:a", 0.3, 0.6)
	icon_tween.parallel().tween_property(next_icon, "position:y", next_icon.position.y + 4, 0.6)
	
	# 0.6秒かけて元の状態に戻る
	icon_tween.tween_property(next_icon, "modulate:a", 1.0, 0.6)
	icon_tween.parallel().tween_property(next_icon, "position:y", next_icon.position.y - 4, 0.6)


# 安全に対象のTweenを消去する
func _clear_tweens():
	if typing_tween:
		typing_tween.kill()
	if icon_tween:
		icon_tween.kill()
