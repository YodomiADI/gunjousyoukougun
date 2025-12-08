extends Node

# セーブファイルの保存場所（user://はPCやスマホのユーザー専用フォルダを指します）
# ベースとなるセーブパス。%dの部分にスロット番号が入ります
const SAVE_PATH_TEMPLATE = "user://savegame_slot_%d.save"
const AUTO_SAVE_SLOT = 0 # オートセーブ用スロット番号（0番とする

# 現在の章を管理する変数
var current_chapter_id = "prologue"
# ゲームの状態を保持する変数（例：現在のテキスト行数）
var current_line_index = 0

# 総プレイ時間（秒）
var total_play_time: float = 0.0

# シナリオデータを辞書で管理 
# キー（"prologue"など）を使ってテキストを取り出します
var scenarios = {
	"prologue": [
		"死期が見えるようになった。\n西暦何年何月何日。\n時間までは書いていない。\nでもその日に必ず死は訪れる。",
		"いつから見えるようになったかは覚えていない。\n最初はただ数字が頭上に浮かんでいるだけだと思っていた。\n俺は不謹慎にもその数字が当日と一致する日を待ちわびてしまった。というのも、\n毎朝元気な挨拶をしてくれる近所のおじいさんがもうすぐでその数字が近づいていたのだ。\n",
		"当日の朝、おじいさんの挨拶はなかった。\n	その日の夕方、",
		"パトカーが物々しく赤いランプを音を立てずに回っていたのが脳裏にこびりついている。\n原因は夜中の心筋梗塞。発見に至ったのはおじいさんと面識のある町内会のおばさん達。\n毎朝のご近所づきあいに決められた時間に世間話しに来なかったため確認しに行ったところ、\n違和感を感じ警察を呼びそのまま確認に至る。\n",
		"そんな詳しい話を晩ご飯の最中に聞かされ、食べ物が喉を通りにくかったことを覚えている。\n	だが、もっと喉を通らなくなったことがある。",
		"近所の野良猫だ。"
	],
	"chapter_1": [
		"【第一章】\n猫の額には、明日の日付が浮かんでいた。",
		"俺はどうすべきか迷った。",
		"運命は変えられるのだろうか？"
	]
}

# 章IDを日本語の表示名に変換する辞書（表示用）
var chapter_names = {
	"prologue": "プロローグ",
	"chapter_1": "第一章"
}


func _ready():
	# GlobalはAutoloadされているので、ゲーム中ずっと動いています。
	# ポーズ中に時間を止める設定はGodotのデフォルト挙動で機能します。
	pass

# 毎フレーム経過時間を加算する
func _process(delta):
	total_play_time += delta

# # ゲームの状態を初期値に戻す機能 
# 「はじめから」を選ぶ際に、章IDも含めて完全にリセットするために使用します。
func reset_game_progress():
	# Global変数を初期値に戻す
	current_chapter_id = "prologue"
	current_line_index = 0
	total_play_time = 0.0 # 時間もリセット
	print("ゲーム進捗をリセットしました: ", current_chapter_id, " ", current_line_index)
	# 注: saveファイル自体を削除することも可能ですが、今回はGlobal変数のリセットに留めます。
	# main_game側からロード処理を削除するため、これで「最初から」の動作は実現できます。

# --- セーブ機能 ---
	# slot_id: 0はオートセーブ、1以上は任意セーブスロット
func save_game(slot_id: int = AUTO_SAVE_SLOT):
	var path = SAVE_PATH_TEMPLATE % slot_id
	var file = FileAccess.open(path, FileAccess.WRITE)
	# 章の情報（chapter_id）も保存する
	# 保存したいデータを辞書形式でまとめる
	var data = {
		"chapter_id": current_chapter_id,
		"line_index": current_line_index,
		"play_time": total_play_time, # 時間も保存
		"timestamp": Time.get_datetime_dict_from_system() # 実際の現実時間（任意）	
	}
	# JSON形式の文字列にして保存
	file.store_string(JSON.stringify(data))
	print("スロット ", slot_id, " にセーブしました: ", current_chapter_id)

# --- ロード機能 ---
func load_game(slot_id: int = AUTO_SAVE_SLOT):
	var path = SAVE_PATH_TEMPLATE % slot_id
	if not FileAccess.file_exists(path):
		return false # ファイルがなければ何もしない

	var file = FileAccess.open(path, FileAccess.READ)
	var json_text = file.get_as_text()
	
	# JSONを解析してデータに戻す
	var json = JSON.new()
	var error = json.parse(json_text)
	
	if error == OK:
		var data = json.data
		current_chapter_id = data.get("chapter_id", "prologue")
		current_line_index = data.get("line_index", 0)
		total_play_time = data.get("play_time", 0.0) # 時間を復元
		print("ロード完了: ", current_chapter_id)
		return true
	return false
# 指定したスロットの「表示用情報」だけを取得する関数
# セーブデータの存在確認や、ボタンのラベル表示に使います
func get_slot_info(slot_id: int) -> Dictionary:
	var path = SAVE_PATH_TEMPLATE % slot_id
	if not FileAccess.file_exists(path):
		return {} # データなし

	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	
	if error == OK:
		return json.data # 辞書データをそのまま返す
	return {}

# 秒数を「時間:分:秒」の文字列に変換するヘルパー
func format_time(seconds: float) -> String:
	var total_sec = int(seconds)
	var h = total_sec / 3600.0
	var m = (total_sec % 3600) / 60.0
	var s = total_sec % 60
	return "%02d:%02d:%02d" % [h, m, s]
