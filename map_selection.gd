# map_selection.gd
func _on_location_pressed(location_id: String):
	# 第2部は遷移ごとに12時間減らす
	Global.advance_all_timers(Global.SECONDS_PER_PERIOD)
	
	# 誰か死んだかチェック
	if Global.pending_death_event != "":
		# 死亡イベントへ強制遷移
		pass
	# 選択前に「死」を判定
	check_character_deaths()
	
	# 死んだヒロインの場所ならイベントを発生させない、等の処理
	if is_character_available(location_id):
		# シナリオ再生へ
		pass
	else:
		# 誰もいない、または死後イベントへ
		pass

# --- 修正案（未来を見据えた形） ---

func check_character_deaths():
	# 全キャラをループでチェックして、HP(white)が0以下のキャラを死亡処理する
	for char_id in Global.death_data.keys():
		var data = Global.death_data[char_id]
		
		# まだ死んでいないのに、寿命が尽きていたら死亡フラグを立てる
		if data["white"] <= 0 and not data["is_dead"]:
			# Globalの関数を呼んで死亡フラグを立てる
			Global.mark_as_dead(char_id)
			play_death_effect(char_id) # IDをそのまま渡すのが楽です

func is_character_available(location_id: String) -> bool:
	# キャラIDと場所を紐付けるテーブルなどがあると管理が楽になります
	if location_id == "church":
		# ココロネが死んでいるかチェック
		if Global.death_data["Kokorone"]["is_dead"]:
			return false
	return true
