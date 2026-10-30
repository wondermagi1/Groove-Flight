shader_type spatial;
render_mode unshaded, cull_disabled;
uniform bool corona = false;
varying vec3 object_point;
void vertex() { object_point=VERTEX; }
float flare(vec3 p) {
    return sin(p.x*19.0+sin(p.y*11.0+TIME*0.30)*2.0) *
           sin(p.y*21.0+sin(p.z*14.0-TIME*0.24)) *
           sin(p.z*18.0+TIME*0.20);
}
void fragment() {
    vec3 p=normalize(object_point);
    float granular=flare(p)*0.5+0.5;
    float edge=1.0-max(dot(normalize(NORMAL),normalize(VIEW)),0.0);
    vec3 light=mix(vec3(1.0,0.25,0.035),vec3(1.0,0.88,0.34),granular);
    if (corona) {
        ALBEDO=vec3(1.0,0.43,0.09);
        EMISSION=vec3(1.0,0.25,0.025)*0.5;
        ALPHA=pow(edge,2.8)*0.13;
    } else {
        ALBEDO=light;
        EMISSION=light*1.35;
    }
}
