extends Resource
class_name ScenarioData

# この章のID（例: "day_1", "day_7_happy"）
@export var chapter_id: String = ""

# この章のタイトル（セーブ画面やチャプター選択での表示用）
@export var title: String = ""

# 背景画像
@export var background: Texture2D

# BGM
@export var bgm: AudioStream

# テキストデータの配列（マルチライン文字列で入力しやすくする）
@export_multiline var texts: Array[String] = []

# 次に進む章のID（自動で進む場合）
# 分岐がある場合や、この章で終わりの場合は空欄にする
@export var next_chapter_id: String = ""

# 第2部へ移行するかどうかのフラグ
@export var is_end_of_part1: bool = false
