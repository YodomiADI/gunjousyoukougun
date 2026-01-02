# ScenarioData.gd
extends Resource
class_name ScenarioData

# 次に起こるアクションの定義
enum NextAction { 
	AUTO_NEXT,      # 指定した次の章へ自動で進む（第1部用）
	OPEN_MAP,       # マップ選択画面を開く（第2部用）
	DETERMINE_END,  # 8日目のエンディング判定へ進む
	GO_TO_TITLE     # タイトル画面へ戻る
}


@export_group("Basic Info")
@export var chapter_id: String = ""           # 章のID（例: "day1_am_church"）
@export var chapter_title: String = ""        # セーブデータ等に表示する名前
@export var events: Array[DialogueEvent] = [] # セリフの配列

@export_group("Flow Control")
@export var next_action: NextAction = NextAction.AUTO_NEXT
@export var next_chapter_id: String = ""      # AUTO_NEXTの時に次に呼ぶリソース名

@export_group("Flags")
@export var reward_flag: String = ""          # 読み終わった時に貰えるフラグ（例: "心その1"）

@export_enum("None", "Heart", "Flame", "Soul") var reward_type: String = "None"
