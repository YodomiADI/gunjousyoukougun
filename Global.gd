# Global.gd
extends Node

# --- 1. 基本的な進行状況 ---
var current_chapter_id: String = "prologue"
var current_line_index: int = 0
var flags: Dictionary = {}
var total_play_time: float = 0.0

# --- 2. 第2部用ステータス ---
var is_part2: bool = false
var current_day: int = 1
var current_period: int = 0  # 0:午前, 1:午後

# 第2部用ポイント（個数管理）
var heart_count: int = 0 # 心
var flame_count: int = 0 # 焔
var soul_count: int = 0  # 魂

# --- 3. 死期システム関連 ---
var is_timer_active: bool = false
# 現在の章での「死期の底（これ以上減らない値）」
var current_death_floor: float = 0.0

# 秒単位での残り寿命
var player_death_seconds: float = 2587670064.0
var kokorone_death_seconds: float = 582252.0  # 約6日18時間
var homura_death_seconds: float = 600000.0
var rei_death_seconds: float = 600000.0

# 生存フラグ
var is_kokorone_dead: bool = false
var is_homura_dead: bool = false
var is_rei_dead: bool = false

# --- 4. システム設定・定数 ---
var system_data = {
	"is_part1_cleared": false
}

const SAVE_PATH = "user://save_%d.dat"
const SYSTEM_SAVE_PATH = "user://system.dat"

# 追加
var is_hovering_proxy: bool = false

# --- 死期システムの定数 ---
# 1日の秒数 (24時間 * 60分 * 60秒)
const SECONDS_PER_DAY = 86400.0
const SECONDS_PER_PERIOD = 43200.0 # 12時間（第2部用）
# --- 死期データの新構造 ---
# white: 本来の死期, red: 変動する死期（-1.0は未設定）, discovered: マウスオーバーしたか
var death_data = {
	"Player":   {"white": 2587670064.0, "red": -1.0, "discovered": true, "is_dead": false},
	"Kokorone": {"white": 1356048000.0, "red": 529200.0, "discovered": false, "is_dead": false},
	"Homura":   {"white": 600000.0,     "red": -1.0, "discovered": false, "is_dead": false},
	"Rei":      {"white": 600000.0,     "red": -1.0, "discovered": false, "is_dead": false}
}
# 次の遷移時に実行すべき死亡イベント（キャラIDを入れる）
var pending_death_event: String = ""
# --- 便利関数（計算・判定用） ---

# 現在表示すべき「死期」の数値を返す（赤優先）
func get_current_death_time(char_id: String) -> float:
	if not death_data.has(char_id): return 0.0
	var data = death_data[char_id]
	# 赤(red)が設定されていればそれを、なければ白(white)を返す
	return data["red"] if data["red"] > 0 else data["white"]

# キャラクターを発見（マウスオーバー）した時に呼ぶ
func discover_death_time(char_id: String):
	if death_data.has(char_id):
		death_data[char_id]["discovered"] = true
		
# 死期を減らす（時間経過）
func advance_death_time(char_id: String, seconds: float):
	if not death_data.has(char_id) or death_data[char_id]["is_dead"]: return
	
	var data = death_data[char_id]
	if data["red"] > 0:
		data["red"] = max(0, data["red"] - seconds)
	else:
		data["white"] = max(0, data["white"] - seconds)
	
	# 0になったら死亡フラグを立てる
	if get_current_death_time(char_id) <= 0:
		data["is_dead"] = true
		pending_death_event = char_id # 次の画面遷移でイベント発生

# 全員の死期を一括で進める（第1部・第2部用）
func advance_all_timers(seconds: float):
	for char_id in death_data.keys():
		advance_death_time(char_id, seconds)
		
# シナリオのリソース登録
var scenario_registry = {
	"prologue": "res://scenarios/prologue.tres",
	"day_1": "res://scenarios/day_1.tres",
	"day_2": "res://scenarios/day_2.tres",
	"day_3": "res://scenarios/day_3.tres",
	"day_4": "res://scenarios/day_4.tres",
	"day_5": "res://scenarios/day_5.tres",
	"day_6": "res://scenarios/day_6.tres",
	"day_7": "res://scenarios/day_7.tres",
	"happy_end1": "res://scenarios/happy_end.tres",
	"bad_end1": "res://scenarios/bad_end.tres",
	"day1_am_clocktower": "res://scenarios/part2/day1_am_clocktower.tres",
	"day1_am_church": "res://scenarios/part2/day1_am_church.tres",
}

# ---ロード時に背景とBGMを復元するための変数 ---
var current_bg_path: String = ""
var current_bgm_path: String = ""

# 章の日本語名辞書（セーブ画面などで使用）
var chapter_names = {
	"prologue": "プロローグ",
	"day_1": "第一日",
	"day_7": "第七日（審判）",
	"day1_am_church": "第2部 1日目・教会"
}

# 
var death_timers = {
	"Player": 2587670064.0, # プレイヤーも辞書に入れると管理が楽です
	"Kokorone": 582252.0,
	"Homura": 600000.0,
	"Rei": 600000.0
}


# --- 処理部 ---

func _ready():
	load_system_data()

var is_loading_process: bool = false

	
# --- 死期システム ---
# タイマーが動いているかどうかのフラグ
var is_death_timer_active: bool = true

func _process(delta):
	# 第1部や第2部で、タイマーを動かしたいシーンの時だけ減らす
	if is_death_timer_active:
		# 全員の寿命を現実の1秒（delta）ずつ減らしていく
		advance_all_timers(delta)
		
	if not get_tree().paused:
		# プレイヤーの死期を減らすが、current_death_floor よりは減らさない
		if player_death_seconds > current_death_floor:
			player_death_seconds -= delta
			if player_death_seconds < current_death_floor:
				player_death_seconds = current_death_floor
		
		# ヒロインたちのタイマー（こちらは制限なし、または別途管理）
		if is_timer_active:
			update_heroine_timers(delta)
	# ゲーム中（メイン画面が表示されている間）だけカウントを進める
	# シーン名が "MainGame"（または実際のメインシーン名）であることを確認してください
	if get_tree().current_scene and get_tree().current_scene.name == "MainGame":
		total_play_time += delta

func update_heroine_timers(delta):
	if not is_kokorone_dead: death_timers["Kokorone"] = max(0, death_timers["Kokorone"] - delta)
	if not is_homura_dead: death_timers["Homura"] = max(0, death_timers["Homura"] - delta)
	if not is_rei_dead: death_timers["Rei"] = max(0, death_timers["Rei"] - delta)

func add_flag(flag_name: String):
	if flag_name == "": return
	flags[flag_name] = true
	_check_special_conditions()

func _check_special_conditions():
	if flags.has("心その1") and flags.has("心その2") and flags.has("心その3"):
		flags["ココロネ"] = true

func get_scenario_resource(id: String) -> ScenarioData:
	if scenario_registry.has(id):
		return load(scenario_registry[id]) as ScenarioData
	return null
# --- 章開始時に死期を「1日分」確定させる関数 ---
func prepare_death_timer_for_next_day():
	# 現在の死期から、次の「24時間区切り」まで強制的に進める
	# 例：プロローグ開始時 63日 3:33:18 
	# -> 1章開始時には必ず 62日 3:33:18 からスタートさせる
	
	player_death_seconds -= SECONDS_PER_DAY
	
	# この章で減ってもいい限界（さらに1日分先）を設定
	current_death_floor = player_death_seconds - SECONDS_PER_DAY
# --- セーブ・ロード ---

func save_game(slot_id: int):
	var data = {
		# 基本進行
		"current_chapter_id": current_chapter_id,
		"current_line_index": current_line_index,
		"flags": flags,
		
		# 死期システム（最新の変数たち）
		"player_death_seconds": player_death_seconds,
		"current_death_floor": current_death_floor,
		"death_timers": death_timers, # 辞書ごと保存
		"death_data": death_data, # 辞書ごと保存
		"pending_death_event": pending_death_event,
		
		# 第2部ステータス
		"heart_count": heart_count,
		"flame_count": flame_count,
		"soul_count": soul_count,
		"is_part2": is_part2,
		"current_day": current_day,
		"current_period": current_period,
		"current_bg_path": current_bg_path,
		"current_bgm_path": current_bgm_path,
		
		"total_play_time": total_play_time
	
	}
	var file = FileAccess.open(SAVE_PATH % slot_id, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		print("Saved to slot: ", slot_id)

func load_game(slot_id: int) -> bool:
	var path = SAVE_PATH % slot_id
	if not FileAccess.file_exists(path): return false
	
	var file = FileAccess.open(path, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	death_data = data.get("death_data", death_data)
	pending_death_event = data.get("pending_death_event", "")
	
	# データの復元
	total_play_time = data.get("total_play_time", 0.0)
	
	current_bg_path = data.get("current_bg_path", "")
	current_bgm_path = data.get("current_bgm_path", "")
	
	current_chapter_id = data.get("current_chapter_id", "prologue")
	current_line_index = data.get("current_line_index", 0)
	flags = data.get("flags", {})
	
	player_death_seconds = data.get("player_death_seconds", player_death_seconds)
	current_death_floor = data.get("current_death_floor", 0.0)
	death_timers = data.get("death_timers", death_timers)
	
	heart_count = data.get("heart_count", 0)
	flame_count = data.get("flame_count", 0)
	soul_count = data.get("soul_count", 0)
	
	is_part2 = data.get("is_part2", false)
	current_day = data.get("current_day", 1)
	current_period = data.get("current_period", 0)
	
	is_loading_process = true # ロード中フラグを立てる
	# ロードに成功したらメイン画面へ遷移する
	get_tree().change_scene_to_file("res://main_game.tscn")
	return true

func save_system_data():
	var file = FileAccess.open(SYSTEM_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(system_data))

func load_system_data():
	if FileAccess.file_exists(SYSTEM_SAVE_PATH):
		var file = FileAccess.open(SYSTEM_SAVE_PATH, FileAccess.READ)
		system_data = JSON.parse_string(file.get_as_text())

# --- ユーティリティ ---

func format_death_time(total_seconds: float) -> String:
	var s = int(total_seconds)
	var years = s / (365 * 24 * 3600.0)
	s %= (365 * 24 * 3600)
	var months = s / (30 * 24 * 3600.0)
	s %= (30 * 24 * 3600)
	var days = s / (24 * 3600.0)
	s %= (24 * 3600)
	var hours = s / 3600.0
	s %= 3600
	var minutes = s / 60.0
	s %= 60
	var seconds = s
	return "%d：%d：%d：%d：%02d：%02d" % [years, months, days, hours, minutes, seconds]

func evaluate_part2_ending() -> String:
	if heart_count >= 3 and flame_count >= 3 and soul_count >= 3: return "true_end"
	if heart_count >= 3: return "kokorone_end"
	return "bad_end"

# 初期化用（はじめから用）
func reset_game_progress():
	total_play_time = 0.0  # 時間を0に戻す
	current_chapter_id = "prologue"
	current_line_index = 0
	flags = {}
	is_part2 = false
	current_day = 1
	current_period = 0
	is_timer_active = false
	# 他の変数も初期値にリセット
	
	
# バックログを保存する配列（辞書の配列）
var backlog: Array[Dictionary] = []
# バックログの最大保存件数（溜まりすぎ防止）
const MAX_BACKLOG = 100

# バックログにセリフを追加する関数
func add_to_backlog(char_name: String, text: String):
	var entry = {
		"name": char_name,
		"text": text
	}
	backlog.append(entry)
	
	# 上限を超えたら古いものから削除
	if backlog.size() > MAX_BACKLOG:
		backlog.remove_at(0)

# ゲームリセット時などにログを消去する関数
func clear_backlog():
	backlog.clear()

func get_death_time_string(char_name: String) -> String:
	if death_timers.has(char_name):
		return format_death_time(death_timers[char_name])
	return ""
# スロットの情報を取得する関数（ポーズメニューやロード画面用）
func get_slot_info(slot_id: int) -> Dictionary:
	var path = SAVE_PATH % slot_id
	if not FileAccess.file_exists(path):
		return {} # ファイルがない場合は空の辞書を返す

	var file = FileAccess.open(path, FileAccess.READ)
	var json_text = file.get_as_text()
	var data = JSON.parse_string(json_text)
	
	if data == null:
		return {}

	return {
		"chapter_id": data.get("current_chapter_id", "不明"),
		"play_time": data.get("total_play_time", 0)
	}

# セーブデータの削除関数（タイトル画面の削除モード用）
func delete_save(slot_id: int):
	var path = SAVE_PATH % slot_id
	if FileAccess.file_exists(path):
		var dir = DirAccess.open("user://")
		if dir:
			dir.remove(path.replace("user://", ""))
			print("削除成功: ", path)

# 通常のプレイ時間フォーマット (秒 -> 00:00:00)
func format_time(total_seconds: float) -> String:
	var s = int(total_seconds)
	var hours = s / 3600.0
	var minutes = (s % 3600) / 60.0
	var seconds = s % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]
# --- 全データの初期化（初期化ボタン用） ---
func initialize_all_data():
	# 1. すべてのセーブファイルを削除 (0:オート, 1~3:手動スロット)
	for i in range(4):
		delete_save(i)
	
	# 2. システムデータ（クリアフラグなど）をリセット
	system_data = {
		"is_part1_cleared": false,
		"is_part2_unlocked": false
	}
	save_system_data() # リセットしたシステム状態を保存
	
	# 3. 現在進行中のデータ（プレイ時間など）をすべてリセット
	reset_game_progress()
	
	print("すべてのデータを初期化しました。")
