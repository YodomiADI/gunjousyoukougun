// water_ripple.gdshader
shader_type canvas_item;
render_mode unshaded;

// Godot 4 の機能で現在の画面バッファをキャプチャ
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// 最大同時波紋数（GDScript側と必ず一致させること）
const int MAX_RIPPLES = 10;

uniform vec2 ripple_positions[MAX_RIPPLES];
uniform float ripple_ages[MAX_RIPPLES];

// --- 調整パラメータ ---
uniform float ripple_strength : hint_range(0.0, 0.03) = 0.017;
uniform float wave_speed      : hint_range(0.0, 1.0)  = 0.28;
uniform float frequency       : hint_range(5.0, 80.0) = 50.0;
uniform float time_decay      : hint_range(0.0, 5.0)  = 5;
uniform float max_age          : hint_range(0.5, 5.0)  = 2.8;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 total_offset = vec2(0.0);

	// スクリーンのアスペクト比補正（画面が横長でも波紋を綺麗な正円にする）
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;

	for (int i = 0; i < MAX_RIPPLES; i++) {
		float age = ripple_ages[i];

		// 非アクティブ（0.0以下）または寿命切れはスキップ
		if (age <= 0.0 || age >= max_age) {
			continue;
		}

		vec2 diff = uv - ripple_positions[i];
		diff.x *= aspect; // X方向をスケールして円形に補正
		float dist = length(diff);

		if (dist < 0.0005) {
			continue;
		}

		// 波紋が広がっていく前面の半径
		float wave_radius = age * wave_speed;

		// ガウシアンエンベロープ（波紋の線の太さ・広がりを制御）
		float front_sigma = 0.10;
		float front_env = exp(-pow((dist - wave_radius) / front_sigma, 2.0));

		// 時間経過による減衰
		float age_env = exp(-age * time_decay);

		// 実際の波の変位計算
		float wave = cos(dist * frequency - age * 14.0) * front_env * age_env;

		// 放射方向のベクトル（アスペクト比を元に戻して正規化）
		vec2 radial = diff;
		radial.x /= aspect;
		radial = normalize(radial);

		total_offset += radial * wave * ripple_strength;
	}

	// 歪ませたUVで画面テクスチャをサンプリング
	COLOR = texture(SCREEN_TEXTURE, uv + total_offset);
}