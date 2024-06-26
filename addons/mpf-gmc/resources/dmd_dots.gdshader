// Shader to create DMD-style dot overlays
// without impacting the underlying screen texture

shader_type canvas_item;

uniform vec4 color : source_color;
uniform float hardness = 5.0;
uniform float spacing = 2.0;
uniform float columns = 128.0;
uniform float rows = 32.0;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture;

void fragment() {
	vec2 ratio = vec2(1.0, rows / columns); // make sure the dots are going to be 1:1
	float dots = length(fract(SCREEN_UV * columns * ratio) - vec2(0.5)) * spacing; // fracts the UV to make it loop, substract it by half then turn it into circle (using length) and finally multiply with 2 for smaller circle
	dots = (1.0 - dots) * hardness; // invert the dot then make it look hard so soft circle is no more
	dots = clamp(dots, 0.0, 1.0); // limit the value to 1.0, otherwise it would add your pixel's brightness instead of being a border (this is because some of it's value is above 1.0)
	COLOR = mix(color, texture(SCREEN_TEXTURE, UV), dots);
}