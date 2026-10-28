shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_tex:hint_screen_texture,filter_linear;
uniform float strength=.3;
void fragment(){
 vec3 col=texture(screen_tex,SCREEN_UV).rgb;
 float vignette=smoothstep(.40,.85,length(SCREEN_UV-.5));
 col*=1.-vignette*.20*strength;
 col*=1.-.025*strength*(.5+.5*sin(SCREEN_UV.y*1080.*3.14159));
 COLOR=vec4(col,1.);
}
