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


# character_manager.gd 内

# キャラ（立ち絵）にマウスが乗った
func _on_left_char_proxy_mouse_entered():
	
	# $LeftSlot は CharacterDisplay クラスなので、その中の関数を呼ぶ
	$LeftSlot._on_mouse_entered()

func _on_left_char_proxy_mouse_exited():
	
	$LeftSlot._on_mouse_exited()

# タイマー（数字）にマウスが乗った
func _on_left_timer_proxy_mouse_entered():
	Global.is_hovering_proxy = true
	# LeftSlotの中にある timer_label ノードの関数を直接呼ぶ
	$LeftSlot.timer_label._on_area_2d_mouse_entered()

func _on_left_timer_proxy_mouse_exited():
	Global.is_hovering_proxy = false
	$LeftSlot.timer_label._on_area_2d_mouse_exited()

# キャラ（立ち絵）にマウスが乗った
func _on_right_char_proxy_mouse_entered():
	
	# $RightSlot は CharacterDisplay クラスなので、その中の関数を呼ぶ
	$RightSlot._on_mouse_entered()

func _on_right_char_proxy_mouse_exited():
	
	$RightSlot._on_mouse_exited()

# タイマー（数字）にマウスが乗った
func _on_right_timer_proxy_mouse_entered():
	Global.is_hovering_proxy = true
	# RightSlotの中にある timer_label ノードの関数を直接呼ぶ
	$RightSlot.timer_label._on_area_2d_mouse_entered()

func _on_right_timer_proxy_mouse_exited():
	Global.is_hovering_proxy = false
	$RightSlot.timer_label._on_area_2d_mouse_exited()

# キャラ（立ち絵）にマウスが乗った
func _on_center_char_proxy_mouse_entered():

	# $CenterSlot は CharacterDisplay クラスなので、その中の関数を呼ぶ
	$CenterSlot._on_mouse_entered()

func _on_center_char_proxy_mouse_exited():
	
	$CenterSlot._on_mouse_exited()

# タイマー（数字）にマウスが乗った
func _on_center_timer_proxy_mouse_entered():
	Global.is_hovering_proxy = true
	# CenterSlotの中にある timer_label ノードの関数を直接呼ぶ
	$CenterSlot.timer_label._on_area_2d_mouse_entered()

func _on_center_timer_proxy_mouse_exited():
	Global.is_hovering_proxy = false
	$CenterSlot.timer_label._on_area_2d_mouse_exited()
