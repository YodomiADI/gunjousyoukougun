extends Control # または Node2D など

func _ready():
	# 第2部の初期化
	print("第2部開始")
	
	# 第1部のBGMを止める、または第2部のBGMを再生
	# Global変数の save_game() を呼べば、ここでもセーブが可能

# 第2部独自のゲームロジックをここに書く
