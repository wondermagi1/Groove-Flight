shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 body_color : source_color = vec4(0.35, 0.5, 0.7, 1.0);
uniform int planet_style = 0;
uniform float seed = 0.0;
varying vec3 object_point;

float hash3(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}
float noise3(vec3 p) {
    vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hash3(i), hash3(i+vec3(1,0,0)),f.x),
                   mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),
               mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),
                   mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}
float fbm(vec3 p) { return noise3(p)*0.57 + noise3(p*2.03+7.1)*0.28 + noise3(p*4.1-2.7)*0.15; }
void vertex() { object_point = VERTEX; }
void fragment() {
    vec3 p = normalize(object_point);
    float terrain = fbm(p*5.0 + seed*4.7);
    float fine = noise3(p*36.0 + seed);
    vec3 col = mix(body_color.rgb*0.36,body_color.rgb*1.24,terrain);
    float glow = 0.0;
    float bands = sin(p.y*32.0 + terrain*8.0);
    if (planet_style == 0) {
        float crater = smoothstep(0.72,0.80,noise3(p*23.0+seed));
        col = mix(vec3(0.19,0.21,0.24), vec3(0.62,0.58,0.50), terrain);
        col *= 0.75 + fine*0.30; col = mix(col,col*0.34,crater*0.72);
    } else if (planet_style == 1) {
        float clouds = fbm(p*9.0 + vec3(TIME*0.016,seed,0.0));
        col = mix(vec3(0.36,0.14,0.065),vec3(0.98,0.70,0.30),clouds);
        col *= 0.88 + bands*0.10;
        glow = smoothstep(0.75,0.84,fine)*0.12;
    } else if (planet_style == 2) {
        float land = smoothstep(0.49,0.56,terrain);
        vec3 sea = mix(vec3(0.025,0.13,0.38),vec3(0.08,0.43,0.62),terrain);
        col = mix(sea,mix(vec3(0.06,0.28,0.20),vec3(0.52,0.65,0.35),fine),land);
        float clouds = smoothstep(0.61,0.77,fbm(p*8.5+vec3(TIME*0.009,2.0,1.0)));
        col = mix(col,vec3(0.86,0.93,1.0),clouds*0.85);
        col = mix(col,vec3(0.84,0.94,1.0),smoothstep(0.79,0.97,abs(p.y)));
    } else if (planet_style == 3) {
        col = mix(vec3(0.28,0.09,0.055),vec3(0.84,0.35,0.15),terrain);
        col = mix(col,vec3(0.26,0.08,0.04),smoothstep(0.69,0.76,noise3(p*12.0))*.62);
        col = mix(col,vec3(0.80,0.70,0.60),smoothstep(0.88,0.99,abs(p.y)));
    } else if (planet_style == 4 || planet_style == 5) {
        float stripes = sin(p.y*45.0 + terrain*4.0 + sin(p.x*9.0)*0.7);
        col = mix(body_color.rgb*0.47,body_color.rgb*1.23,stripes*0.5+0.5);
        col = mix(col,vec3(0.91,0.81,0.63),smoothstep(0.15,0.55,stripes)*0.30);
        vec2 storm = vec2((p.x-0.34)*2.8,(p.y+0.22)*6.0);
        col = mix(col,vec3(0.50,0.18,0.11),exp(-dot(storm,storm)*8.0)*0.73);
    } else if (planet_style == 6) {
        col = mix(vec3(0.11,0.37,0.47),vec3(0.56,0.89,0.91),terrain);
        col = mix(col,vec3(0.68,0.93,0.95),smoothstep(0.64,0.78,terrain)*0.4);
        col *= 0.95 + bands*0.045;
    } else {
        col = mix(vec3(0.018,0.055,0.26),vec3(0.16,0.39,0.93),terrain);
        col *= 0.87 + sin(p.y*48.0 + terrain*11.0)*0.12;
        float vortex = exp(-pow((p.y+0.19)*15.0,2.0)-pow((p.x-0.38)*8.0,2.0));
        col = mix(col,vec3(0.025,0.05,0.16),vortex*0.8);
        col = mix(col,vec3(0.42,0.66,0.95),smoothstep(0.66,0.79,fine)*0.11);
    }
    float rim = pow(1.0-max(dot(normalize(NORMAL),normalize(VIEW)),0.0),3.0);
    ALBEDO = col;
    ROUGHNESS = planet_style == 2 ? 0.42 : 0.77;
    METALLIC = 0.0;
    SPECULAR = 0.34;
    EMISSION = body_color.rgb * rim * 0.10 + vec3(1.0,0.28,0.02)*glow;
}
