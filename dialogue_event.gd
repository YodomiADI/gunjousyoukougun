# DialogueEvent.gd
extends Resource
class_name DialogueEvent

enum CharacterPos { NONE, LEFT, RIGHT, CENTER } # 表示位置の定義
@export var position: CharacterPos = CharacterPos.CENTER # デフォルトを真ん中に

enum CharID { NONE, KOKORONE, HOMURA, REI }
@export var char_id: CharID = CharID.NONE # これで誰のタイマーか判定する

@export_group("Text")
@export var character_name: String = ""       # キャラ名（空なら名前枠非表示）
@export_multiline var text: String = ""       # セリフ本文

@export_group("Visual")
@export var character_sprite: Texture2D       # 立ち絵
@export var background: Texture2D             # 背景（変更時のみセット）
@export var char_expression: String = ""      # (任意) 表情の識別子（"angry", "smile"など）
@export var timer_offset: Vector2 = Vector2(0, -450) # デフォルトで少し上に設定
@export var base_scale: float = 1.0      # 素材本来の大きさを調整する用
@export var character_scale: float = 1.0 # 1.0 が標準。1.2なら20%拡大、0.8なら20%縮小。

@export_group("Audio")
@export var bgm: AudioStream                  # BGM（変更時のみセット）
@export var se: AudioStream                   # 効果音（再生したい時のみセット）

@export_group("Effect")
@export var shake_screen: bool = false        # 画面を揺らす演出をするか

@export_group("Position Control")
@export var clear_other_slots: bool = true # デフォルトは「消す（今まで通り）」
