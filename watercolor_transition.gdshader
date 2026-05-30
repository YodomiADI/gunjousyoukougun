// watercolor_transition.gdshader
// 水彩絵の具が画面を塗りつぶしていくようなトランジション演出
// FadeOverLay (ColorRect) に ShaderMaterial として適用する
shader_type canvas_item;

// ============================================================
// ノイズテクスチャ（Godotエディタで2つ用意してセットする）
// ============================================================
// [base_noise の設定推奨値]
//   Noise Type  : Simplex Smooth
//   Frequency   : 0.005 〜 0.01  （大きなモヤモヤ）
//   Fractal Type: FBM
//   Seamless    : ON
uniform sampler2D base_noise : repeat_enable;

// [detail_noise の設定推奨値]
//   Noise Type        : Cellular
//   Frequency         : 0.05 〜 0.1  （紙のザラザラ感）
//   Fractal Type      : FBM
//   Cellular Return   : Distance
//   Seamless          : ON
uniform sampler2D detail_noise : repeat_enable;

// ============================================================
// トランジション制御パラメータ
// ============================================================

// 進行度（GDScriptのTweenでここを 0.0 → 1.0 に動かす）
// 0.0 = 完全に透明（元の画面が見える）
// 1.0 = 完全に塗りつぶし（水彩色で画面が覆われる）
uniform float progress : hint_range(0.0, 1.0) = 0.0;

// 境界のぼかし幅（大きいほどじわっとした滲みになる）
uniform float smoothness : hint_range(0.01, 0.4) = 0.08;

// ============================================================
// 見た目のパラメータ
// ============================================================

// 水彩絵の具の色（画面を塗りつぶす色）
// 白っぽい紙の色や、絵柄に合わせた色に変えてOK
uniform vec4 ink_color : source_color = vec4(0.96, 0.94, 0.88, 1.0);

// 絵の具のフチ（溜まり）の色
// 水彩特有の「乾いた縁」の濃い部分を表現する
uniform vec4 edge_color : source_color = vec4(0.55, 0.65, 0.75, 1.0);

// フチの濃さ（0.0でフチなし、2.0で濃い縁）
uniform float edge_intensity : hint_range(0.0, 3.0) = 1.2;

// ベースノイズとディテールノイズの合成比率
// 0.0 = ディテールのみ / 1.0 = ベースのみ
uniform float noise_blend : hint_range(0.0, 1.0) = 0.65;

// ============================================================
// 内部アニメーション（オプション）
// ============================================================

// 塗りつぶし中にゆらゆらと動くアニメーション速度
// 0.0 にすると完全に静止した絵になる
uniform float flow_speed : hint_range(0.0, 1.0) = 0.5;

// UVのタイリング倍率（1.0で画面ぴったり、2.0で2倍の密度）
uniform float noise_scale : hint_range(0.5, 4.0) = 2.0;

void fragment() {
	// --------------------------------------------------------
	// 1. ノイズ合成（水彩のシミ形状を決定する）
	// --------------------------------------------------------

	// 時間経過でノイズをゆっくり流す（生き生きとした絵の具感）
	vec2 flow_offset = vec2(TIME * flow_speed * 0.03, TIME * flow_speed * 0.02);
	vec2 scaled_uv = UV * noise_scale;

	float b = texture(base_noise,   scaled_uv + flow_offset).r;
	float d = texture(detail_noise, scaled_uv - flow_offset * 0.5).r;

	// ベース（大きなモヤモヤ）とディテール（紙のザラザラ）を合成
	float combined = mix(d, b, noise_blend);

	// --------------------------------------------------------
	// 2. マスク計算（どこまで塗られているかを決める）
	// --------------------------------------------------------

	// smoothstep で境界をぼかし、水彩のじわっとした滲みを再現
	float mask = smoothstep(progress - smoothness, progress + smoothness, combined);

	// --------------------------------------------------------
	// 3. 水彩フチ（絵の具の溜まり）を計算する
	// --------------------------------------------------------
	// トランジション境界のごく狭い範囲だけを検出して色を濃くする

	float edge_low  = smoothstep(progress - smoothness,       progress,                combined);
	float edge_high = smoothstep(progress,                    progress + smoothness,    combined);
	float edge_band = edge_low - edge_high; // 境界部分だけが 1.0 になる帯

	// --------------------------------------------------------
	// 4. 最終カラーの合成
	// --------------------------------------------------------

	// 水彩色のベースにフチ色を乗せる
	vec3 painted_rgb = mix(ink_color.rgb, edge_color.rgb, edge_band * edge_intensity);

	// mask に基づいてアルファを決定
	// mask=0 → 透明（元の画面が透けて見える）
	// mask=1 → 不透明（水彩色で塗られた）
	float final_alpha = mask;

// progress が完全に 0.0（密封）になった時のドット抜け・ちらつき防止
	// progressが 0.05 から 0.0 に近づくにつれて、強制的に alpha を 1.0 (完全不透明) にする
	final_alpha = mix(1.0, final_alpha, smoothstep(0.0, 0.05, progress));

	COLOR = vec4(painted_rgb, final_alpha);
}
