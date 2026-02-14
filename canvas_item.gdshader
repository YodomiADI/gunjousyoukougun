//canvas_item.gdshader
shader_type canvas_item;

// --- 画像設定 ---
uniform sampler2D paper_mask_texture : filter_linear_mipmap; // 紙枠の画像
uniform sampler2D noise_texture : repeat_enable;             // ★追加: 揺らぎ用のノイズ画像

// --- 調整パラメータ ---
uniform float bleed_strength : hint_range(0.1, 5.0) = 1.0;   // 滲みの強さ
uniform bool multiply_paper_texture = true;                  // 紙の質感を合成するか

// --- ★揺らぎ設定 ---
uniform float shimmer_speed : hint_range(0.0, 1.0) = 0.05;   // 揺れる速さ
uniform float shimmer_amount : hint_range(0.0, 0.1) = 0.005; // 揺れる幅（大きくしすぎないのがコツ）

void fragment() {
	// 1. ノイズを動かすためのUV計算
	// 時間(TIME)を使って、ノイズ画像を斜めにスクロールさせます
	vec2 noise_uv = UV + vec2(TIME * shimmer_speed, TIME * shimmer_speed * 0.5);

	// 2. ノイズの値を取得 (0.0 ～ 1.0)
	float noise_val = texture(noise_texture, noise_uv).r;

	// 3. マスクを読み取る位置をずらす（ここが魔法の正体）
	// ノイズの値を使って、本来見るべき場所(UV)から少しだけズラした場所(distorted_uv)を作ります
	vec2 distorted_uv = UV + (vec2(noise_val) - 0.5) * shimmer_amount;

	// --- ここからは前回とほぼ同じ ---

	// 街並みは「ズレていない」本来のUVで取得（絵自体はグニャグニャさせないため）
	vec4 main_color = texture(TEXTURE, UV);

	// 紙枠（マスク）は「ズラした」UVで取得（これでフチだけがウネウネする）
	vec4 mask_color = texture(paper_mask_texture, distorted_uv);

	// 輝度計算
	float mask_luminance = dot(mask_color.rgb, vec3(0.299, 0.587, 0.114));

	// 滲み処理（時間経過で少しだけ滲み具合を脈動させる演出も隠し味で追加）
	float breathing = sin(TIME * 2.0) * 0.1; // -0.1 ~ +0.1 の範囲で呼吸する
	float current_bleed = bleed_strength + breathing;
	float alpha = smoothstep(0.0, 1.0 / current_bleed, mask_luminance);

	// 色の合成
	if (multiply_paper_texture) {
		COLOR = main_color * mask_color;
	} else {
		COLOR = main_color;
	}

	COLOR.a = alpha;
}