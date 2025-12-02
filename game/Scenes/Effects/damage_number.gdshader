shader_type canvas_item;

uniform float split : hint_range(0,1) = 0.5;
uniform float darken_strength : hint_range(0,1) = 0.25; // lower = subtle, higher = darker

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    if (tex.a < 0.01) discard;

    vec4 final_color = tex;

    // UV.y goes from 0 (top) to 1 (bottom)
    if (UV.y > split) {
        // Darken by multiplying RGB
        final_color.rgb *= (1.0 - darken_strength);
    }

    COLOR = final_color;
}
