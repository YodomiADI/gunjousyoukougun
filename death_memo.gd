# death_memo.gd
extends Control
signal closed # 閉じたことを知らせるためのカスタムシグナル

func _ready():
	hide()

# 手記が開かれた時に呼ばれる関数
func open_memo():
	update_display()
	show()

func _on_back_button_pressed():
	hide()       # 手記画面を隠す
	closed.emit() # シグナルを発信
	
# （必要に応じて閉じるボタンなどを追加した時用）
func close_memo():
	hide()

# --- 画面の表示を更新する関数 ---
func update_display():
	# Playerだけは常に「今」の真実の時間を手記に反映させる場合
	Global.record_observed_time("Player")
	# Globalのdeath_dataから、全員分の情報を順番にチェックする
	for char_id in Global.death_data.keys():
		var data = Global.death_data[char_id]
		
		# ユニークネーム(%)を使って、対応するラベルを取得する
		var white_label = get_node_or_null("%" + char_id + "WhiteLabel") as Label
		var red_label = get_node_or_null("%" + char_id + "RedLabel") as Label
		
		# ラベルが見つからなかったらスキップ (Player用などUIがない場合を考慮)
		if not white_label and not red_label:
			continue
			
		# --- 観測済み（マウスオーバーしたことがある）場合 ---
		# --- 1. すでに死亡している場合 ---
		if data["is_dead"]:
			if white_label:
				white_label.text = "―― 終焉 ――"
				white_label.modulate = Color.DARK_GRAY # 死亡者はグレーアウト
			if red_label:
				red_label.text = "――――"
				red_label.modulate = Color.DARK_GRAY
			continue # 死亡していたら以下の処理はスキップ
			
		# --- 2. 観測済み（マウスオーバーしたことがある）場合 ---
		if data["discovered"]:
			# 文字色を元に戻す（琥珀色や白など）
			if white_label:
				white_label.modulate = Color.WHITE
				white_label.text = format_memo_time(data["last_seen_white"])
			
			if red_label:
				red_label.modulate = Color.RED # 歪みは赤っぽく
				if data["last_seen_red"] > 0:
					red_label.text = format_memo_time(data["last_seen_red"])
				else:
					red_label.text = "――"
					
		# --- まだ観測していない（???）場合 ---
		else:
			if white_label:
				white_label.text = "？？？"
			if red_label:
				red_label.text = "？？？"




# --- 手記専用のフォーマット変換関数 ---
# 秒数を受け取って「〇年 〇ヶ月 〇日 〇時間 〇分 〇秒」の文字列にする
func format_memo_time(total_seconds: float) -> String:
	# 1. まず int に変換して、小数の計算ミスを防ぐ
	var s = int(total_seconds)

	if s <= 0: return "0年 0ヶ月 0日 00時間 00分 00秒"
	if s > 4000000000: return "計測不能（永劫）"
	
	# 2. 各単位の秒数をあらかじめ整数で定義
	var sec_year  = 31536000 # 365 * 24 * 3600
	var sec_month = 2592000  # 30 * 24 * 3600
	var sec_day   = 86400    # 24 * 3600
	
	# 3. 順次計算（すべて int 同士の計算にする）
	var years = floori(s / float(sec_year))
	s %= sec_year
	
	var months = floori(s / float(sec_month))
	s %= sec_month
	
	var days = floori(s / float(sec_day))
	s %= sec_day
	
	var hours = floori(s / 3600.0)
	s %= 3600
	
	var minutes = floori(s / 60.0)
	var seconds = s % 60
	
	# 4. 「0」をあえて表示するスタイル
	return "%d年 %dヶ月 %d日 %02d時間 %02d分 %02d秒" % [
		years, months, days, hours, minutes, seconds
	]
