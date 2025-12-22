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
# クリアフラグ（第2部解放用）
var is_part1_cleared: bool = false


# ★変更：シナリオIDと、リソースファイルのパスを紐付ける辞書
# ここで登録しておけば、ファイル名を変えてもIDで呼び出せます
var chapter_registry = {
	"prologue": "res://scenarios/prologue.tres",
	"day_1": "res://scenarios/day_1.tres",
	"day_2": "res://scenarios/day_2.tres",
	"day_3": "res://scenarios/day_3.tres",
	"day_4": "res://scenarios/day_4.tres",
	"day_5": "res://scenarios/day_5.tres",
	"day_6": "res://scenarios/day_6.tres",
	"day_7": "res://scenarios/day_7.tres",
	"happy_end": "res://scenarios/happy_end.tres",
	"bad_end": "res://scenarios/bad_end.tres"
}

# 章IDを日本語の表示名に変換する辞書（表示用）
var chapter_names = {
	"prologue": "プロローグ",
	"day_1": "Day 1",
	"day_2": "Day 2",
	"day_3": "Day 3",
	"day_4": "Day 4",
	"day_5": "Day 5",
	"day_6": "Day 6",
	"day_7": "Day 7 (分岐点)",
	"happy_end": "ハッピーエンド",
	"bad_end": "バッドエンド"
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
		"timestamp": Time.get_datetime_dict_from_system(), # 実際の現実時間（任意）	
		"is_part1_cleared": is_part1_cleared # ★クリア状況も保存する
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
		is_part1_cleared = data.get("is_part1_cleared", false) # ★復元
		print("ロード完了: ", current_chapter_id)
		return true
	return false
	
# IDからリソースデータをロードして返す便利関数
func get_scenario_data(id: String) -> ScenarioData:
	if chapter_registry.has(id):
		var path = chapter_registry[id]
		# ResourceLoaderを使ってtresファイルを読み込む
		return ResourceLoader.load(path) as ScenarioData
	else:
		push_error("未登録のチャプターID: " + id)
		return null
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

# --- 削除機能 ---
func delete_save(slot_id: int):
	var path = SAVE_PATH_TEMPLATE % slot_id
	
	# ファイルが存在する場合のみ削除を実行
	if FileAccess.file_exists(path):
		# Godot 4系でのファイル削除方法
		DirAccess.remove_absolute(path)
		print("スロット", slot_id, "のデータを削除しました")
		return true
	return false
	
# --- 全データ初期化（初期化ボタン用） ---
func initialize_all_data():
	# 1. メモリ上の変数をすべて初期値に戻す
	current_chapter_id = "prologue"
	current_line_index = 0
	total_play_time = 0.0
	is_part1_cleared = false
	
	# システムデータ辞書も初期化
	system_data = {
		"is_part1_cleared": false,
		"unlocked_gallery": []
	}
	
	# 2. 物理ファイルの削除
	# スロット0〜20を削除
	for i in range(21):
		var path = SAVE_PATH_TEMPLATE % i
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
			print("削除成功: ", path)
	
	# システムデータの削除
	if FileAccess.file_exists(SYSTEM_SAVE_PATH):
		DirAccess.remove_absolute(SYSTEM_SAVE_PATH)
		print("システムデータを削除しました")


#-----システムセーブ機能-----
# システムデータ（クリア状況やCG回収率など、全体で共有するデータ）
const SYSTEM_SAVE_PATH = "user://system_data.save"
var system_data = {
	"is_part1_cleared": false,  # 第1部クリアフラグ
	"unlocked_gallery": []      # (将来用) CGギャラリーなど
}

# システムデータを保存する
func save_system_data():
	var file = FileAccess.open(SYSTEM_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(system_data))
	print("システムデータを保存しました")

# システムデータを読み込む（起動時に呼ぶ）
func load_system_data():
	if not FileAccess.file_exists(SYSTEM_SAVE_PATH):
		return # ファイルがない場合は初期値のまま

	var file = FileAccess.open(SYSTEM_SAVE_PATH, FileAccess.READ)
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	
	if error == OK:
		var data = json.data
		# 既存の辞書にマージする（キーが足りない場合のエラー防止）
		if data.has("is_part1_cleared"):
			system_data["is_part1_cleared"] = data["is_part1_cleared"]
		# 必要に応じて他のデータも読み込む

# 第1部クリア時に呼ぶ便利関数
func complete_part1():
	system_data["is_part1_cleared"] = true
	save_system_data() # 即座にファイルに書き込む
