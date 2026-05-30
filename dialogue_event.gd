# DialogueEvent.gd
extends Resource
class_name DialogueEvent

# 表示位置の定義
enum CharacterPos { NONE, LEFT, RIGHT, CENTER }

# 背景トランジションの種類
# エディタのインスペクターで各セリフごとに選択できる
enum BgTransition {
	## 章が変わり背景も変わる（最初のイベント）
	## 同じ章内で背景を切り替えたい
	AUTO,       # 【デフォルト】背景が変わる時だけ水彩トランジション。章移行直後は重複しないよう自動スキップ。
	## 背景を切り替えるがトランジション不要
	NONE,       # トランジションなし。背景を即座に差し替える。
	## 同じ背景のまま演出として水彩を挟みたい
	WATERCOLOR  # 背景が変わらなくても強制的に水彩トランジションを実行する。演出上の強調に使う。
}

@export_group("Text")
@export var character_name: String = ""       # キャラ名（空なら名前枠非表示）
@export_multiline var text: String = ""       # セリフ本文

@export_group("Visual")
@export var position: CharacterPos = CharacterPos.CENTER # 立ち絵の表示位置
@export var character_sprite: Texture2D       # 立ち絵
@export var char_expression: String = ""      # (任意) 表情の識別子（"angry", "smile"など）
@export var background: Texture2D             # 背景（変更時のみセット）
@export var bg_transition: BgTransition = BgTransition.AUTO #この行の背景トランジションの種類。AUTOで通常の自動判定。
@export var base_scale: float = 1.0          # 素材本来の大きさを調整する用
@export var character_scale: float = 1.0      # 1.0 が標準。1.2なら20%拡大、0.8なら20%縮小。
@export var timer_offset: Vector2 = Vector2() # タイマーの表示位置微調整

@export_group("Audio")
@export var bgm: AudioStream                  # BGM（変更時のみセット）
@export var se: AudioStream                   # 効果音（再生したい時のみセット）

@export_group("Effect")
@export var shake_screen: bool = false        # 画面を揺らす演出をするか
@export var clear_other_slots: bool = true    # 次のセリフに進む際、他のスロットの立ち絵を消すか

@export_group("System Commands")
## trueにすると、このセリフの時にクリック進行を止め、対象キャラへのマウスオーバーを待つ
@export var require_hover_tutorial: bool = false
## チュートリアルや選択肢、死期表示で対象とするキャラID。
## バグ防止のため、Global.death_dataのキー（"Player", "Kokorone", "Homura", "Rei", "Cat"）と完全に一致させてください。
@export var target_char_id: String = ""

@export_group("Choices & Branching")
## 選択肢として表示されるテキストのリスト
@export var choices: Array[String] = []
## 分岐先シナリオID（選択肢の数と合わせる。空文字ならそのまま次の行へ）
@export var choice_next_scenario_ids: Array[String] = []
## 各選択肢を選んだ時の死期増減（秒）。マイナスなら死期が縮む。
@export var choice_time_modifiers: Array[float] = [] 
## 選択肢ボタンでの死期表示タイプ（0:Auto, 1:White, 2:Red）※要素数はchoicesと合わせてください
@export var choice_time_display_types: Array[int] = []

@export_group("Choices Disable Conditions")
## 無効化条件: 対象キャラID ("Kokorone"など)。空文字なら判定なし ※要素数はchoicesと合わせてください
@export var disable_target_chars: Array[String] = []
## 無効化条件: 判定に使う死期 (1: White, 2: Red) ※0や未設定は判定なし ※要素数はchoicesと合わせてください
@export var disable_time_types: Array[int] = []
## 無効化条件: 対象の死期がこの秒数「以下」ならボタンを押せなくする ※要素数はchoicesと合わせてください
@export var disable_thresholds: Array[float] = []
