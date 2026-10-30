shader_type canvas_item;
render_mode unshaded;
uniform float travel=0.;
uniform vec2 world_position=vec2(0.);
uniform int planet_style=0;
uniform vec4 planet_color : source_color=vec4(.56,.58,.63,1.);
uniform vec4 sky_tint : source_color=vec4(.04,.05,.09,1.);
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 uv=UV; vec2 p=(uv-.5)*vec2(1.77778,1.);
 float cloud=noise(p*3.+world_position*.00004)*.65+noise(p*7.)*.25;
 vec3 col=mix(vec3(.005,.008,.026),sky_tint.rgb*.45+vec3(.004,.008,.016),cloud);
 col+=vec3(.004,.012,.034)*smoothstep(.55,0.,length(p-vec2(.3,-.1)));
 float glow=exp(-length(p-vec2(.72,-.57))*4.);
 col+=vec3(.018,.037,.055)*glow;
 // A subdued planetary limb: scenery, never a full-screen beat flash.
 vec2 planet=p-vec2(.64,-.48)-world_position*.000002; float d=length(planet);
 float edge=exp(-abs(d-.65)*155.);
 vec2 q=planet/.65;
 float latitude=q.y;
 float terrain=noise(q*9.+float(planet_style)*5.);
 float bands=.5+.5*sin(latitude*31.+noise(q*4.)*4.);
 vec3 albedo=planet_color.rgb*(.45+terrain*.5);
 if(planet_style==1) albedo=mix(albedo*.35,vec3(1.,.21,.055),pow(1.-abs(terrain-.5)*2.,14.));
 if(planet_style==2){
  albedo=mix(vec3(.09,.29,.48),vec3(.14,.35,.24),smoothstep(.49,.56,noise(q*5.)));
  albedo=mix(albedo,vec3(.48,.60,.66),smoothstep(.65,.78,noise(q*12.+vec2(travel*.15,0.)))*.5);
 }
 if(planet_style==3) albedo*=.70+noise(q*vec2(4.,14.))*.5;
 if(planet_style==4 || planet_style==5) albedo*=.58+bands*.55;
 if(planet_style==6) albedo=mix(albedo,vec3(.63,.82,.86),smoothstep(.6,.83,terrain)*.6);
 if(planet_style==7) albedo*=.6+sin(latitude*20.+terrain*8.)*.24;
 float z=sqrt(max(0.,1.-dot(q,q)));
 float lighting=max(.05,dot(normalize(vec3(q,z)),normalize(vec3(-.65,-.4,1.))));
 float body=1.-smoothstep(.645,.65,d);
 if(planet_style==5){
  vec2 ring_uv=vec2(planet.x+planet.y*.30,planet.y*3.2);
  float ring_distance=length(ring_uv);
  float rings=smoothstep(.72,.74,ring_distance)*(1.-smoothstep(.99,1.03,ring_distance));
  col+=planet_color.rgb*rings*(.017+.018*sin(ring_distance*210.))*(1.-body);
 }
 col=mix(col,albedo*(.045+lighting*.065),body);
 col+=planet_color.rgb*edge*.15;
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
