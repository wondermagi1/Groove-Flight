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
  p+=vec2(.20,.35); lit_color=vec4(.015,.025,.045,COLOR.a*.22);
 }else{
  p+=vec2(-.035,-.32)*UV.x;
  float shade=1.;
  if(UV.y<4.){
   vec2 normal=rotation*vec2(cos(UV.y),sin(UV.y));
   shade=.48+.38*max(0.,dot(normal,normalize(vec2(-.6,-.8))));
  }else{shade=.98;}
  lit_color=vec4(COLOR.rgb*shade,COLOR.a);
 }
 VERTEX=inverse_rotation*p;
}
void fragment(){COLOR=lit_color;}
