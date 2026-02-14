shader_type canvas_item;
render_mode unshaded; // ライトの影響を無視して白飛びを防止

uniform sampler2D noise_texture : repeat_enable;
uniform float effect_strength : hint_range(0.0, 1.0) = 0.5;
uniform float speed : hint_range(0.0, 2.0) = 0.3;
uniform vec4 glow_color : source_color = vec4(0.0, 0.5, 1.0, 1.0); // 群青色の泡

void fragment() {
    // 1. 元の数字の形を取得
    vec4 tex_color = texture(TEXTURE, UV);

    // 透明な部分は描画しない
    if (tex_color.a < 0.01) {
        discard;
    }

    // 2. 泡が昇るアニメーション（UVを縦方向にスクロール）
    vec2 noise_uv = UV;
    noise_uv.y -= TIME * speed;
    // X方向にも少し揺らすとより泡らしくなります
    noise_uv.x += sin(TIME * speed * 0.5 + UV.y) * 0.1;

    float noise_val = texture(noise_texture, noise_uv).r;

    // 3. 泡の粒を際立たせる (stepやpowを使ってコントラストを上げる)
    float bubbles = pow(noise_val, 3.0) * effect_strength;

    // 4. 合成：元の色の上に群青色の泡を乗せる
    // 元の色と泡の色をミックス
    vec3 final_rgb = mix(tex_color.rgb, glow_color.rgb, bubbles);

    // ほんの少しだけ発光感を足す
    final_rgb += glow_color.rgb * bubbles * 0.5;

    COLOR = vec4(final_rgb, tex_color.a);
}