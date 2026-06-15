shader_type canvas_item;

uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    vec4 inverted = vec4((1.0 - color.rgb), color.a);
    COLOR = inverted * tint_color;
}