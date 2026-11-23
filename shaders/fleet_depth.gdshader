shader_type canvas_item;
render_mode unshaded;
varying vec4 lit_color;
void vertex(){
 float heading=INSTANCE_CUSTOM.x;
 float c=cos(heading),s=sin(heading);
 mat2 rotation=mat2(vec2(c,s),vec2(-s,c));
 mat2 inverse_rotation=mat2(vec2(c,-s),vec2(s,c));
 vec2 p=rotation*VERTEX;
 p.y*=.88;
 if(UV.x<-.5){
  p+=vec2(.17,.31); lit_color=vec4(.018,.013,.041,COLOR.a*.18);
 }else{
  p+=vec2(-.035,-.27)*UV.x;
  float shade=1.;
  if(UV.y<4.){
   vec2 normal=rotation*vec2(cos(UV.y),sin(UV.y));
   shade=.48+.42*max(0.,dot(normal,normalize(vec2(-.6,-.8))));
  }else{
   // Constant world-space key light on the machined top face. Emitters keep
   // their colour;there is no synchronized fleet-wide brightness animation.
   shade=UV.y>6.?.99:(.93+.075*dot(normalize(p+vec2(.001)),normalize(vec2(-.6,-.8))));
  }
  vec3 surface=COLOR.rgb;
  if(UV.y>7.5){
   surface=mix(surface,vec3(1.,.72,.29),INSTANCE_CUSTOM.y*.82);
  }
  lit_color=vec4(surface*shade,COLOR.a);
 }
 VERTEX=inverse_rotation*p;
}
void fragment(){COLOR=lit_color;}
