extends Resource
# ↓ これを書くことで、他のスクリプトで「DialogueEvent」という名前が使えるようになります
class_name DialogueEvent

# 表示するテキスト（RichTextLabel用なのでBBCodeが使えます）
@export_multiline var text: String = ""

# --- この行が表示される瞬間に切り替えたい場合のみ設定する ---
@export var change_background: Texture2D # 変更後の背景
@export var change_bgm: AudioStream    # 変更後のBGM
@export var play_se: AudioStream      # 効果音を鳴らす場合
