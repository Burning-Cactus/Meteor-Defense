#version 330

in vec2 fragTexCoord;
uniform sampler2D texture0;
uniform vec2 resolution;
uniform float time;
uniform float ca_strength;
uniform float glow_radius;
uniform float glow_strength;
uniform float noise_strength;
out vec4 finalColor;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main() {
    vec2 uv = fragTexCoord;

    // Chromatic aberration
    vec2 ca_px = ca_strength / resolution;
    float r = texture(texture0, uv + vec2( ca_px.x, 0.0)).r;
    float g = texture(texture0, uv).g;
    float b = texture(texture0, uv + vec2(-ca_px.x, 0.0)).b;
    vec3 col = vec3(r, g, b);

    // Glow: 8-tap neighborhood
    vec2 px = glow_radius / resolution;
    vec3 glow = vec3(0.0);
    glow += texture(texture0, uv + vec2(-px.x,  0.0)).rgb;
    glow += texture(texture0, uv + vec2( px.x,  0.0)).rgb;
    glow += texture(texture0, uv + vec2(  0.0, -px.y)).rgb;
    glow += texture(texture0, uv + vec2(  0.0,  px.y)).rgb;
    glow += texture(texture0, uv + vec2(-px.x, -px.y)).rgb * 0.707;
    glow += texture(texture0, uv + vec2( px.x, -px.y)).rgb * 0.707;
    glow += texture(texture0, uv + vec2(-px.x,  px.y)).rgb * 0.707;
    glow += texture(texture0, uv + vec2( px.x,  px.y)).rgb * 0.707;
    glow /= (4.0 + 4.0 * 0.707);
    col += glow * glow_strength;

    // Noise
    col *= (1.0-noise_strength/1.0) + hash(uv + fract(time)) * noise_strength*2.0;

    finalColor = vec4(col, 1.0);
}
