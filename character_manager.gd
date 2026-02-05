# character_manager.gd
extends Node2D

@onready var slots = {
	DialogueEvent.CharacterPos.LEFT: $LeftSlot,
	DialogueEvent.CharacterPos.RIGHT: $RightSlot,
	DialogueEvent.CharacterPos.CENTER: $CenterSlot
}

func update_portraits(ev: DialogueEvent):
	# 1. 誰も表示しない設定（NONE / 0）の場合
	if ev.position == DialogueEvent.CharacterPos.NONE:
		for slot in slots.values():
			slot.hide()
		return

	# 2. 他のスロットを消す設定なら、まず全員消す
	if ev.clear_other_slots:
		for slot in slots.values():
			slot.hide()

	# 3. 今回のターゲットを表示する
	if slots.has(ev.position):
		var target_slot = slots[ev.position]
		target_slot.display(
			ev.character_name, 
			ev.character_sprite, 
			ev.char_id, 
			ev.timer_offset.y, 
			ev.character_scale, 
			ev.base_scale
		)
		target_slot.show() # 非表示だった場合に備えて出す

	# 4. 「暗くする（フォーカス）」演出
	# 全スロットをチェックして、今回の発言位置(ev.position)と同じなら明るく、違うなら暗くする
	for pos_key in slots:
		var slot = slots[pos_key]
		if slot.visible:
			slot.set_focus(pos_key == ev.position)
