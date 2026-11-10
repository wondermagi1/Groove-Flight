extends RefCounted
## Bind only the active planet. Material references retain shared maps; unused
## Earth layers are released on departure instead of preloading all eight worlds.
const MAPS={
	"mercury":"8k_mercury.jpg","venus":"4k_venus_atmosphere.jpg",
	"earth":"8k_earth_daymap.jpg","mars":"8k_mars.jpg",
	"jupiter":"8k_jupiter.jpg","saturn":"8k_saturn.jpg",
	"uranus":"2k_uranus.jpg","neptune":"2k_neptune.jpg"}
const EARTH_LAYERS={"cloud_map":"8k_earth_clouds.jpg","night_map":"8k_earth_nightmap.jpg","normal_map":"8k_earth_normal_map.png","specular_map":"8k_earth_specular_map.png"}

static func bind_map(material: ShaderMaterial,parameter: String,filename: String) -> Texture2D:
	var path="res://assets/planets/"+filename
	var existing=material.get_shader_parameter(parameter)
	if existing is Texture2D and existing.resource_path==path: return existing
	var texture=load(path) as Texture2D
	if texture==null: push_error("Planet texture missing: "+path)
	material.set_shader_parameter(parameter,texture)
	return texture

static func apply(material: ShaderMaterial,id: String,quality: int=2,exposure: float=.9) -> void:
	bind_map(material,"albedo_map",str(MAPS.get(id,MAPS.mercury)))
	bind_map(material,"star_map","8k_stars_milky_way.jpg")
	for parameter in EARTH_LAYERS:
		if id=="earth": bind_map(material,parameter,EARTH_LAYERS[parameter])
		else: material.set_shader_parameter(parameter,null)
	if id=="saturn": bind_map(material,"ring_map","8k_saturn_ring_alpha.png")
	else: material.set_shader_parameter("ring_map",null)
	material.set_shader_parameter("quality_level",clampi(quality,0,2))
	material.set_shader_parameter("background_exposure",clampf(exposure,.35,1.25))
