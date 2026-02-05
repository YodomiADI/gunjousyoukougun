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
var is_typing: bool = false

func _ready():
	next_icon.hide() # 最初は隠しておく

# メインゲームから「このセリフを出して！」と頼まれる関数
func display_message(char_name: String, full_text: String):
	# 前のタイピングを強制終了
	if typing_tween:
		typing_tween.kill()
	
	name_label.text = char_name
	text_label.text = full_text
	text_label.visible_ratio = 0.0 # 最初は文字を隠す
	next_icon.hide()
	is_typing = true

	# Tweenで文字をじわじわ出す演出
	typing_tween = create_tween()
	# 文字数に応じて時間を変える（全文字出すまで）
	var duration = full_text.length() * typing_speed
	typing_tween.tween_property(text_label, "visible_ratio", 1.0, duration)
	
	# 終わったら完了処理へ
	typing_tween.finished.connect(_on_typing_finished)

# 文字が出終わった時の処理
func _on_typing_finished():
	is_typing = false
	next_icon.show() # 「次へ」の合図を出す
	message_finished.emit() # メインゲームに終わったよと伝える

# タイピング中にクリックされたら「一瞬で全表示」する関数
func skip_typing():
	if is_typing:
		if typing_tween:
			typing_tween.kill()
		text_label.visible_ratio = 1.0
		_on_typing_finished()
		return true # スキップしたよ
	return false # タイピング中じゃなかったよ
