shader_type canvas_item;
render_mode unshaded;
uniform float travel=0.;
uniform vec2 world_position=vec2(0.);
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 uv=UV; vec2 p=(uv-.5)*vec2(1.77778,1.);
 float cloud=noise(p*3.+world_position*.00004)*.65+noise(p*7.)*.25;
 vec3 col=mix(vec3(.005,.008,.026),vec3(.014,.034,.105),cloud);
 col+=vec3(.004,.012,.034)*smoothstep(.55,0.,length(p-vec2(.3,-.1)));
 float glow=exp(-length(p-vec2(.72,-.57))*4.);
 col+=vec3(.018,.037,.055)*glow;
 // A subdued planetary limb: scenery, never a full-screen beat flash.
 vec2 planet=p-vec2(.82,-.80); float d=length(planet);
 float edge=exp(-abs(d-.62)*155.);
 col+=vec3(.035,.13,.16)*edge;
 col*=1.-.5*(1.-smoothstep(.60,.62,d));
 for(int layer=0;layer<3;layer++){
  float z=float(layer)+1.; vec2 cell=uv*vec2(125.,75.)/z+vec2(travel*.12/z,travel*.7/z)+world_position*.001/z;
  vec2 id=floor(cell); vec2 q=fract(cell)-.5;
  float star=pow(max(0.,1.-length(q)*16.),3.)*step(.94,hash(id+z*31.));
  col+=vec3(.35,.47,.59)*star*(.3+.17*z);
 }
 // Sparse perspective grid on the lower field, far below combat contrast.
 float floor_y=max(uv.y-.35,.001); vec2 grid=vec2((uv.x-.5)/floor_y,1./floor_y+travel*.13)+world_position*.0008;
 vec2 lines=abs(fract(grid*2.)-.5)/max(fwidth(grid*2.),vec2(.001));
 float line=1.-min(min(lines.x,lines.y),1.);
 col+=vec3(.025,.13,.30)*line*smoothstep(.38,.95,uv.y)*.55;
 COLOR=vec4(col,1.);
}
