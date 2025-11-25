shader_type canvas_item;

uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D noise_tex;
uniform float edge_width = 0.15;
uniform vec4 edge_color = vec4(1.0, 0.8, 0.3, 1.0); // retro glow edge

void fragment() {
    // Incoming modulate color (from Sprite2D.modulate, etc.)
    vec4 mod_col = COLOR;

    // Base sprite texture
    vec4 tex = texture(TEXTURE, UV);

    // Blocky UV for pixel-style chunks
    // Lower grid = bigger blocks, higher = smaller blocks
    float grid = 16.0; // try 8.0 for very chunky; tweak if needed
    vec2 block_uv = floor(UV * grid) / grid;

    // Noise sample
    float n = texture(noise_tex, block_uv).r;
    float threshold = dissolve_amount;

    // Hard cut: keep pixel if noise >= threshold, else remove completely
    float keep = step(threshold, n); // 1 = keep, 0 = dissolve

    // Apply dissolve mask to the texture
    vec4 out_col = tex * keep;

    // Apply modulate only to RGB so flashes work, alpha stays from tex * keep
    out_col.rgb *= mod_col.rgb;

    COLOR = out_col;
}
