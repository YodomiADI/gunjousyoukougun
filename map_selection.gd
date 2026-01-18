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

func check_character_deaths():
	if Global.kokorone_death_seconds <= 0 and not Global.is_kokorone_dead:
		Global.is_kokorone_dead = true
		play_death_effect("ココロネ")
	# ...他のキャラも判定

func is_character_available(location_id: String) -> bool:
	# 例えば「教会」には「ココロネ」がいる設定なら
	if location_id == "church" and Global.is_kokorone_dead:
		return false
	return true
