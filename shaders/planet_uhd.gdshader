shader_type canvas_item;
render_mode unshaded;
uniform float travel=0.;
uniform float music_pulse=0.;
uniform vec2 world_position=vec2(0.);
uniform int planet_style=0;
uniform vec4 planet_color : source_color=vec4(.56,.58,.63,1.);
uniform vec4 sky_tint : source_color=vec4(.04,.05,.09,1.);
uniform int quality_level=2;
uniform float background_exposure=.9;
uniform sampler2D albedo_map : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D cloud_map : filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D night_map : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D normal_map : hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D specular_map : filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D star_map : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D ring_map : source_color,filter_linear_mipmap_anisotropic,repeat_disable;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1.,0.)),f.x),mix(hash(i+vec2(0.,1.)),hash(i+vec2(1.)),f.x),f.y);}
mat2 turn(float a){return mat2(vec2(cos(a),sin(a)),vec2(-sin(a),cos(a)));}
vec2 globe_uv(vec3 n,float offset){return vec2(atan(n.x,n.z)/TAU+offset,asin(clamp(n.y,-1.,1.))/PI+.5);}
void fragment(){
 vec2 aspect=vec2(SCREEN_PIXEL_SIZE.y/SCREEN_PIXEL_SIZE.x,1.);
 vec2 p=(UV-.5)*aspect;
 vec2 sky_uv=turn(.28)*(UV-.5)*vec2(.54,.38)+vec2(.51,.47)+world_position*.000001;
 vec3 sky=texture(star_map,sky_uv).rgb;
 vec3 col=vec3(.002,.004,.012)+sky*.19+sqrt(max(sky,vec3(0.)))*.012;
 col+=sky_tint.rgb*.012;
 // Quiet far-plane orbital beacons; no full-screen exposure pumping.
 vec2 lane=UV*vec2(3.,2.)+world_position*.000018;
 float beacon=pow(max(0.,1.-length(fract(lane)-.5)*35.),3.);
 col+=vec3(.12,.25,.38)*beacon*(.12+music_pulse*.26);
 vec2 center=vec2(.69,-.41); float radius=.77,offset=.58;
 if(planet_style==1){center=vec2(-.72,-.38);radius=.76;offset=.51;}
 if(planet_style==2){center=vec2(.62,-.25);radius=.65;offset=.57;}
 if(planet_style==3){center=vec2(-.65,.34);radius=.72;offset=.53;}
 if(planet_style==4){center=vec2(.70,-.30);radius=.95;offset=.44;}
 if(planet_style==5){center=vec2(.36,-.13);radius=.42;offset=.48;}
 if(planet_style==6){center=vec2(-.56,-.28);radius=.63;offset=.52;}
 if(planet_style==7){center=vec2(.64,.26);radius=.77;offset=.57;}
 vec2 planet=p-center-world_position*.0000015;
 float d=length(planet),aa=max(fwidth(d)*1.15,.00015);
 float body=1.-smoothstep(radius-aa,radius+aa,d);
 vec3 light_dir=normalize(vec3(-.64,-.42,.64));
 // Render the far ring first, and the near arc over the sphere afterward.
 vec4 ring_color=vec4(0.); float ring_front=0.;
 if(planet_style==5 || planet_style==6){
  vec2 ring=turn(planet_style==5?-.36:1.05)*planet;
  float rd=length(vec2(ring.x,ring.y*(planet_style==5?3.1:4.8)))/radius;
  float span=smoothstep(1.20,1.24,rd)*(1.-smoothstep(2.10,2.14,rd));
  if(planet_style==5){
   vec4 raw=texture(ring_map,vec2(clamp((rd-1.22)/.9,0.,1.),.5));
   ring_color=vec4(raw.rgb*.48,raw.a*span*.82);
   float shadow=.38+.62*smoothstep(.08,.50,abs(ring.x/radius));
   ring_color.rgb*=ring.y<0.?shadow:1.;
  }else{
   float strands=pow(.5+.5*sin(rd*370.),7.);
   ring_color=vec4(planet_color.rgb*.3,strands*span*.13);
  }
  ring_front=step(0.,ring.y);
  col=mix(col,ring_color.rgb,ring_color.a*(1.-body));
 }
 if(d<radius+aa){
  vec2 q=planet/radius;
  vec3 n=normalize(vec3(q,sqrt(max(0.,1.-min(dot(q,q),1.)))));
  vec2 uv=globe_uv(n,offset+travel*.00014);
  vec3 material=texture(albedo_map,uv).rgb;
  vec3 normal=n;
  float mu=dot(n,light_dir);
  if(quality_level==2 && (planet_style==0 || planet_style==3)){
   // Small albedo-relief cue, not a claim that the photograph is elevation.
   vec2 texel=1./vec2(textureSize(albedo_map,0));
   float a=dot(texture(albedo_map,uv-vec2(texel.x,0.)).rgb,vec3(.333));
   float b=dot(texture(albedo_map,uv+vec2(texel.x,0.)).rgb,vec3(.333));
   float c=dot(texture(albedo_map,uv-vec2(0.,texel.y)).rgb,vec3(.333));
   float e=dot(texture(albedo_map,uv+vec2(0.,texel.y)).rgb,vec3(.333));
   normal=normalize(n+vec3((a-b)*.55,(c-e)*.55,0.));
  }
  if(quality_level==2 && planet_style==2){
   vec3 tangent=normalize(vec3(n.z+.00001,0.,-n.x));
   vec3 bitangent=normalize(cross(n,tangent));
   vec3 detail=texture(normal_map,uv).xyz*2.-1.;
   normal=normalize(n+tangent*detail.x*.17+bitangent*detail.y*.17);
  }
  float diffuse=max(dot(normal,light_dir),0.);
  vec3 lit=material*(.018+diffuse*.80);
  if(planet_style==1) lit*=vec3(1.03,.96,.86);
  if(quality_level>0 && planet_style==2){
   vec2 weather_uv=uv+vec2(travel*.00065,0.);
   float clouds=texture(cloud_map,weather_uv).r;
   float coverage=smoothstep(.14,.80,clouds);
   if(quality_level==2){
    float shadow=texture(cloud_map,weather_uv+light_dir.xy*.003).r;
    lit*=1.-smoothstep(.18,.83,shadow)*.38;
    float ocean=texture(specular_map,uv).r;
    vec3 half_dir=normalize(light_dir+vec3(0.,0.,1.));
    float glint=pow(max(dot(n,half_dir),0.),95.)*ocean;
    lit+=vec3(.65,.75,.82)*glint*.25;
   }
   lit=mix(lit,vec3(.63,.72,.83)*(.035+max(mu,0.)*.73),coverage*.92);
   float night=1.-smoothstep(-.10,.18,mu);
   lit+=texture(night_map,uv).rgb*night*.48*(1.-coverage*.75);
  }
  if(quality_level==2 && (planet_style==4 || planet_style==5 || planet_style==7)){
   float micro=noise(uv*vec2(420.,850.));
   lit*=.985+micro*.03;
  }
  float atmosphere=pow(1.-n.z,3.)*smoothstep(-.15,.65,mu);
  if(quality_level>0 && planet_style!=0) lit+=planet_color.rgb*atmosphere*.14;
  col=mix(col,lit*background_exposure,body);
 }
 if(quality_level>0){
  float halo=exp(-max(d-radius,0.)*130./radius)*(1.-body);
  float sun_side=.18+.82*max(dot(normalize(vec3(planet,.25)),light_dir),0.);
  col+=planet_color.rgb*halo*sun_side*(planet_style==0?.025:.18)*background_exposure;
 }
 col=mix(col,ring_color.rgb*background_exposure,ring_color.a*body*ring_front);
 // Tiny navigation stars use screen derivatives, preventing4K moire/sparkle.
 vec2 star_cell=UV*vec2(130.,76.)+world_position*.00025;
 vec2 star_id=floor(star_cell),star_local=fract(star_cell)-.5;
 float point=exp(-dot(star_local,star_local)*1700.)*step(.975,hash(star_id));
 col+=vec3(.36,.48,.64)*point*(1.-body);
 COLOR=vec4(max(col,vec3(0.)),1.);
}
