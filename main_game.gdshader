shader_type canvas_item;

uniform sampler2D noise_tex : repeat_enable;
uniform float speed : hint_range(0.0, 2.0) = 0.5;

// --- 水滴にじみのパラメータ ---
uniform vec2 droplet_center = vec2(0.5, 0.5); // 水滴の落ちる位置 (0.0～1.0)
uniform float droplet_size : hint_range(0.0, 1.0) = 0.0; // 0ならにじみなし、1なら全体
uniform float droplet_blur : hint_range(0.0, 1.0) = 0.3; // にじみの境界の柔らかさ

// --- 表現のパラメータ ---
uniform float max_distortion : hint_range(0.0, 0.2) = 0.08;
uniform vec4 water_color : source_color = vec4(0.2, 0.7, 1.5, 1.0);
uniform float emission_strength : hint_range(0.0, 5.0) = 2.0;

void fragment() {
	// 1. 水滴マスクの作成
	// 現在のピクセルから中心点までの距離を測る
	float dist = distance(UV, droplet_center);
	
	// droplet_size に応じて 1.0（にじむ）か 0.0（にじまない）かのマスクを作る
	// smoothstep を使うことで、水が染み込むような柔らかい境界になる
	float mask = 1.0 - smoothstep(droplet_size - droplet_blur, droplet_size, dist);
	
	// 2. 歪みの計算（マスクを乗算して、水滴の場所だけ歪ませる）
	vec2 noise_uv = UV + (TIME * speed);
	float noise_value = texture(noise_tex, noise_uv).r;
	
	// マスクがかかっている場所だけ座標をずらす
	float current_distortion = max_distortion * mask;
	vec2 distorted_uv = UV + (noise_value - 0.5) * current_distortion;
	
	vec4 main_color = texture(TEXTURE, distorted_uv);
	vec4 clean_color = texture(TEXTURE, UV);
	
	// 3. 燐光の計算（ここもマスクをかけて水滴部分を明るくする）
	float flicker_noise = texture(noise_tex, UV - vec2(TIME * speed * 2.7)).r;
	flicker_noise = smoothstep(0.3, 0.7, flicker_noise);
	
	// マスクされている場所ほど発光を強くする
	float final_emission = emission_strength * flicker_noise * mask;
	vec3 emission_rgb = water_color.rgb * final_emission * main_color.a;

	// 4. 水彩のフチ（にじみ出し）
	float bleed_area = (main_color.a - clean_color.a) * mask;
	vec3 base_rgb = mix(main_color.rgb, water_color.rgb, clamp(bleed_area * 5.0, 0.0, 1.0));

	COLOR.rgb = base_rgb + emission_rgb;
	COLOR.a = main_color.a;
}