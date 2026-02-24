#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

uniform float invertAmount;

// Output fragment color
out vec4 finalColor;

void main() {
	// Texel color fetching from texture sampler
	vec4 texelColor = texture(texture0, fragTexCoord)*colDiffuse*fragColor;
	
	vec4 inverted = vec4(1.0) - texelColor;
	vec4 finalRGB = mix(texelColor, inverted, invertAmount);
	
	// Calculate final fragment color
	finalColor = vec4(finalRGB.rgb, texelColor.a);
}
