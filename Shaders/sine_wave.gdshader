shader_type spatial;

uniform bool freeze_time = false;
uniform vec3 albedo : source_color;
uniform vec3 albedo2 : source_color;
uniform float metallic : hint_range(0.0, 1.0) = 0;
uniform float roughness : hint_range(0.0, 1.0) = 0.02;

group_uniforms WaveParameters;
uniform int WaveCount : hint_range(0,8) = 0;
uniform float WaveLengths[8];
uniform float WaveAmplitudes[8];
uniform float WaveDirectionsDegrees[8];
uniform float WaveFrequencies[8];
uniform float WaveSpeeds[8];
uniform float WavePhases[8];
group_uniforms;

group_uniforms EdgeParameters;
uniform float edge_scale = 0.1;
uniform float near = 1.0;
uniform float far = 100.0;
uniform vec3 edge_color : source_color;
group_uniforms;

group_uniforms DepthParameters;
uniform vec4 color_deep : source_color;
uniform vec4 color_shallow : source_color;
uniform float beers_law = 2.0;
uniform float depth_offset = -0.75;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
group_uniforms;

varying vec3 world_coordinates;
varying vec2 wave1;
varying vec2 wave2;
varying vec2 wave3;

float fresnel(float amount, vec3 normal, vec3 view) {
	return pow((1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0)), amount);
}
// Edge depth calculation
float edge(float depth){
	depth = 2.0 * depth - 1.0;
	return near * far / (far + depth * (near - far));
}
vec3 P_DEG(float x, float z, float t, float Wavelength, float Amplitude, float DirectionDegrees, float Frequency, float Speed, float PhaseDegrees) {
	vec2 Direction = vec2( sin(DirectionDegrees * TAU / 360.0), cos(DirectionDegrees * TAU / 360.0 ));
	float p = PhaseDegrees * TAU / 360.0;
	vec3 result;
	result.x = ((Wavelength * Amplitude) * Direction.x * sin(TAU * Frequency * dot(Direction, vec2(x, z)) + (Speed * (t+p))));
	result.y = Wavelength * sin(TAU * Frequency * dot(Direction, vec2(x, z)) + (Speed * (t+p)));
	result.z = ((Wavelength * Amplitude) * Direction.y * sin(TAU * Frequency * dot(Direction, vec2(x, z)) + (Speed * (t+p))));
	
	return result;
}
vec3 N_DEG(float x, float z, float t, float Wavelength, float Amplitude, float DirectionDegrees, float Frequency, float Speed, float PhaseDegrees) {
	vec2 Direction = vec2( sin(DirectionDegrees * TAU / 360.0), cos(DirectionDegrees * TAU / 360.0 ));
	float p = PhaseDegrees * TAU / 360.0;
	vec3 result;
	result.x = (-1.0) * (Direction.x * Frequency * Amplitude * (cos((Frequency * TAU * dot(Direction, vec2(x, z))) + Speed * (t+p))));
	result.y = 1.0 - (Wavelength * Frequency * Amplitude * sin((Frequency * TAU * dot(Direction, vec2(x, z))) + Speed * (t+p)));
	result.z = (-1.0) * (Direction.y * Frequency * Amplitude * (cos((Frequency * TAU * dot(Direction, vec2(x, z))) + Speed * (t+p))));
	
	return result;
}
// Vertex Shader
void vertex() {
	float time = TIME; //TIME;
	
	time = time * float(!freeze_time);
	world_coordinates = VERTEX;
	vec2 wave_coords = world_coordinates.xz;
	vec3 vertexWave = vec3(0,0,0);
	for (int i = 0; i < WaveCount; i++) {
		vertexWave += P_DEG(wave_coords.x, wave_coords.y, time, WaveLengths[i], WaveAmplitudes[i], WaveDirectionsDegrees[i], WaveFrequencies[i], WaveSpeeds[i], WavePhases[i]);
	}
	vertexWave = vertexWave / float(WaveCount);
	if (WaveCount > 0) {
		VERTEX += vertexWave;
	}
	
	// Calculate normal for each wave, take average
	vec3 normalWave = vec3(0,0,0);
	for (int i = 0; i < WaveCount; i++) {
		normalWave += N_DEG(wave_coords.x, wave_coords.y, time, WaveLengths[i], WaveAmplitudes[i], WaveDirectionsDegrees[i], WaveFrequencies[i], WaveSpeeds[i], WavePhases[i]);
	}
	normalWave = normalize(normalWave / float(WaveCount));
	if (WaveCount > 0) {
		NORMAL = normalize(normalWave);
	}
}

void fragment() {
	//Depth variables and calc
	float depth_texture = texture(DEPTH_TEXTURE, SCREEN_UV).r * 2.0 - 1.0;
	float depth = PROJECTION_MATRIX[3][2] / (depth_texture + PROJECTION_MATRIX[2][2]);
	float depth_blend = exp((depth + VERTEX.z + depth_offset) * -beers_law);
	depth_blend = clamp(1.0 - depth_blend, 0.0, 1.0);
	float depth_blend_power = clamp(pow(depth_blend, 2.5), 0.0, 1.0);
	
	vec3 screen_color = textureLod(SCREEN_TEXTURE, SCREEN_UV, depth_blend_power + 2.5).rgb;
	vec3 depth_color = mix(color_shallow.rgb, color_deep.rgb, depth_blend_power);
	vec3 color = mix(screen_color * depth_color, depth_color * 0.25, depth_blend_power * 0.5);
	
	//Get edge depth calc
	float z_depth = edge(texture(DEPTH_TEXTURE, SCREEN_UV).x);
	float z_pos = edge(FRAGCOORD.z);
	float z_dif = z_depth - z_pos;
	
	float fresnel = fresnel(5.0, NORMAL, VIEW);
	vec3 surface_color = mix(albedo, albedo2, fresnel); //interpolate albedo values by fresnel
	vec3 depth_color_adj = mix(edge_color, color, step(edge_scale, z_dif));
	
	ALBEDO = clamp(surface_color + depth_color_adj, vec3(0.0), vec3(1.0));
	METALLIC = metallic;
	ROUGHNESS = roughness;
}
