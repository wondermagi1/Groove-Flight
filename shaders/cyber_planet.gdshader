shader_type spatial;
render_mode unshaded;
uniform vec4 body_color : source_color=vec4(.4,.2,.7,1.);
uniform int planet_style=0;
uniform float seed=0.;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
 vec3 neon=mix(body_color.rgb,vec3(.56,.22,.86),.5);
 vec2 tiles=UV*vec2(32.,18.);vec2 cell=floor(tiles);vec2 f=fract(tiles);
 float value=hash(cell+seed);
 float cel=floor(clamp(dot(normalize(NORMAL),normalize(vec3(-.5,.6,.8))),0.,1.)*3.)/3.;
 vec3 plate=mix(vec3(.025,.018,.06),neon*.28,cel)*(.75+floor(value*3.)*.15);
 vec2 a=max(fwidth(tiles),vec2(.001));vec2 g=min(f,1.-f);
 float seam=max(1.-smoothstep(.02,.02+a.x,g.x),1.-smoothstep(.02,.02+a.y,g.y));
 plate*=1.-seam*.8;
 float wire=(1.-smoothstep(.015,.015+a.y,abs(f.y-.25)))*step(.72,value)*step(.15,f.x)*step(f.x,.82);
 float rim=pow(1.-max(dot(normalize(NORMAL),normalize(VIEW)),0.),3.);
 ALBEDO=plate;EMISSION=neon*(wire*.65+rim*.5);
}
