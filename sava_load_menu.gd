# save_load_menu.gd
extends Control

# trueならセーブ画面、falseならロード画面として動作
var is_save_mode: bool = true 

# --- UIノードへの参照 ---
@onready var title_label = $Title

# スロットボタンを配列で管理（1から始まるため、0番目は空にするか割り当てに注意）
# ※ノード名は実際のシーンに合わせて調整してください
@onready var slot_buttons = {
	1: $Slot1Button,
	2: $Slot2Button,
	3: $Slot3Button
}

func _ready():
	# 1. モードに応じてタイトル表記を切り替え
	if title_label:
		if is_save_mode:
			title_label.text = "セーブデータを選択してください"
		else:
			title_label.text = "ロードデータを選択してください"
			
	# 2. 最新のセーブデータ状況をボタンのテキストや有効化状態に反映
	update_slots_display()

# --- 各スロットのボタンが押された時の処理 ---

func _on_slot_1_pressed():
	execute_action(1)

func _on_slot_2_pressed():
	execute_action(2)

func _on_slot_3_pressed():
	execute_action(3)

# --- セーブ・ロードの実行コアロジック ---
func execute_action(slot_id: int):
	if is_save_mode:
		# セーブ実行
		Global.save_game(slot_id)
		print("スロット ", slot_id, " にセーブしました")
		queue_free() # セーブ完了したら画面を閉じる
	else:
		# ロード実行
		if Global.load_game(slot_id):
			print("スロット ", slot_id, " からロード成功")
			# 状況に応じて、ロード成功時も queue_free() で画面を閉じる場合はここに追記
			queue_free()
		else:
			print("データがありません（通常はボタンが無効化されているためここには来ません）")

# --- セーブデータの有無を調べてボタンを更新する親切設計 ---
func update_slots_display():
	for slot_id in slot_buttons.keys():
		var btn = slot_buttons[slot_id]
		if not btn: continue
		
		# Globalからスロットの情報を取得
		var data = Global.get_slot_info(slot_id)
		
		if data.is_empty():
			# データが無い場合
			btn.text = "スロット %d : -- データなし --" % slot_id
			
			if is_save_mode:
				# セーブ時は、空きスロットにも保存できるので有効のまま
				btn.disabled = false
			else:
				# ロード時は、データが無いので選べないようにする
				btn.disabled = true
		else:
			# データが有る場合（チャプター名とプレイ時間を表示）
			var ch_name = Global.chapter_names.get(data["chapter_id"], data["chapter_id"])
			var time_str = Global.format_time(data.get("play_time", 0))
			
			if is_save_mode:
				btn.text = "スロット %d : %s / %s (上書き)" % [slot_id, ch_name, time_str]
			else:
				btn.text = "スロット %d : %s / %s" % [slot_id, ch_name, time_str]
				
			btn.disabled = false # データがあるので当然有効

# 「戻る」ボタン
func _on_back_button_pressed():
	queue_free() # 画面を閉じる
