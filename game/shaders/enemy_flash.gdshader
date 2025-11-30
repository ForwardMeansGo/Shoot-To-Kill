shader_type canvas_item;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float alpha = tex.a;
	
	// Original texture color
	vec3 base_rgb = tex.rgb;
	
	// Pure white flash color
	vec3 flash_rgb = vec3(1.0, 1.0, 1.0);
	
	// Mix between base and flash based on flash_amount
	vec3 final_rgb = mix(base_rgb, flash_rgb, flash_amount);
	
	COLOR = vec4(final_rgb, alpha);
}

