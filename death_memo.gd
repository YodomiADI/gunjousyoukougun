# death_memo.gd
extends Control

func _ready():
	hide()

# 手記が開かれた時に呼ばれる関数
func open_memo():
	update_display()
	show()

# （必要に応じて閉じるボタンなどを追加した時用）
func close_memo():
	hide()

# --- 画面の表示を更新する関数 ---
func update_display():
	# Globalのdeath_dataから、全員分の情報を順番にチェックする
	for char_id in Global.death_data.keys():
		var data = Global.death_data[char_id]
		
		# ユニークネーム(%)を使って、対応するラベルを取得する
		var white_label = get_node_or_null("%" + char_id + "WhiteLabel")
		var red_label = get_node_or_null("%" + char_id + "RedLabel")
		
		# ラベルが見つからなかったらスキップ (Player用などUIがない場合を考慮)
		if not white_label and not red_label:
			continue
			
		# --- 観測済み（マウスオーバーしたことがある）場合 ---
		if data["discovered"]:
			# 正史死期（白）の更新
			if white_label:
				white_label.text = format_memo_time(data["last_seen_white"])
			
			# 歪み死期（赤）の更新
			if red_label:
				if data["last_seen_red"] > 0:
					red_label.text = format_memo_time(data["last_seen_red"])
				else:
					red_label.text = "――" # 赤の死期がない場合
					
		# --- まだ観測していない（???）場合 ---
		else:
			if white_label:
				white_label.text = "？？？"
			if red_label:
				red_label.text = "？？？"

signal closed # 閉じたことを知らせるためのカスタムシグナル

func _on_back_button_pressed():
	hide()       # 手記画面を隠す
	closed.emit() # シグナルを発信

# --- 手記専用のフォーマット変換関数 ---
# 秒数を受け取って「〇年 〇ヶ月 〇日 〇時間 〇分 〇秒」の文字列にする
func format_memo_time(total_seconds: float) -> String:
	if total_seconds < 0:
		return "不明"
		
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
	
	var text = ""
	# 0年の時は「年」を表示しないなど、手記らしいスッキリとした見た目に調整
	if years > 0: 
		text += "%d年 " % years
	if months > 0: 
		text += "%dヶ月 " % months
	if days > 0: 
		text += "%d日 " % days
		
	text += "%02d時間 %02d分 %02d秒" % [hours, minutes, seconds]
	
	return text
