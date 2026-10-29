"""Original BeatDrift city, authored in Blender. No downloaded or commercial assets.

Run through MCP with exec(compile(Path(__file__).read_text(), __file__, 'exec')),
or blender --background --python tools/build_neon_city.py. Creates a NEW scene;
existing scenes and files are never cleared. Blender Z is up; glTF converts to Y up.
"""
import bpy
import math
import random
import json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/city"
SOURCE = ROOT / "source_art/city"
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)
random.seed(4219)
previous_scene = bpy.context.window.scene if bpy.context.window else bpy.context.scene
scene = bpy.data.scenes.new("BEATDRIFT_Neon_City_Original")
if bpy.context.window:
    bpy.context.window.scene = scene
else:
    bpy.context.window_manager.windows[0].scene = scene
collection = bpy.data.collections.new("CITY_Editable_Architecture")
scene.collection.children.link(collection)
objects = []

def attach(obj, name, mat=None):
    obj.name = name
    for col in list(obj.users_collection):
        col.objects.unlink(obj)
    collection.objects.link(obj)
    if mat:
        obj.data.materials.append(mat)
    objects.append(obj)
    return obj

def material(name, color, metal=0.0, rough=.4, glow=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    node = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    node.inputs["Base Color"].default_value = (*color, 1)
    node.inputs["Metallic"].default_value = metal
    node.inputs["Roughness"].default_value = rough
    node.inputs["Emission Color"].default_value = (*color, 1)
    node.inputs["Emission Strength"].default_value = glow
    mat.diffuse_color = (*color, 1)
    return mat

M = {
    "hull": material("Hull · blue titanium", (.055,.095,.16),.78,.3),
    "edge": material("Chamfer · brushed alloy", (.2,.29,.37),.8,.28),
    "black": material("Joint · graphite", (.012,.023,.042),.5,.42),
    "ground": material("Plaza · basalt ceramic", (.07,.12,.18),.4,.5),
    "glass": material("Curtain wall · midnight glass", (.025,.095,.16),.88,.12),
    "white": material("Porcelain · spacecraft shell", (.63,.75,.81),.6,.3),
    "cyan": material("NEON · ion cyan", (.02,.65,1),.2,.3,5.0),
    "blue": material("NEON · deep violet", (.16,.17,1),.2,.3,3.0),
    "amber": material("NEON · docking amber", (1,.36,.045),.2,.3,3.0),
    "window": material("Occupied window · ice", (.2,.48,.63),.3,.25,1.3),
}

def cube(name, loc, size, mat, bevel=.08, rot=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    ob=attach(bpy.context.object,name,M[mat])
    ob.dimensions=size
    ob.rotation_euler[2]=rot
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod=ob.modifiers.new("Machined edge radius","BEVEL")
        mod.width=bevel
        mod.segments=2
        mod=ob.modifiers.new("Weighted corner normals","WEIGHTED_NORMAL")
        mod.keep_sharp=True
    return ob

def cylinder(name, loc, radius, depth, mat, vertices=64, rotation=(0,0,0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rotation)
    ob=attach(bpy.context.object,name,M[mat])
    mod=ob.modifiers.new("CNC bevel","BEVEL"); mod.width=.055; mod.segments=2
    return ob

def torus(name,loc,major,minor,mat,rotation=(0,0,0),segments=96):
    bpy.ops.mesh.primitive_torus_add(major_segments=segments,minor_segments=8,location=loc,
        major_radius=major,minor_radius=minor,rotation=rotation)
    ob=attach(bpy.context.object,name,M[mat])
    for poly in ob.data.polygons: poly.use_smooth=True
    return ob

def beam(name,a,b,width,mat,depth=None):
    a=Vector(a); b=Vector(b)
    ob=cube(name,(a+b)*.5,(width,depth or width,(b-a).length),mat,min(.07,width*.16))
    ob.rotation_euler=(b-a).to_track_quat("Z","Y").to_euler()
    return ob

def ring_segment(name,radius,angle,span,z,thickness,mat,width=.35):
    # Wedge-shaped architectural panel with an actual open center.
    steps=max(2,int(span*12))
    verts=[]
    for height in (z-thickness*.5,z+thickness*.5):
        for r in (radius-width*.5,radius+width*.5):
            for i in range(steps+1):
                t=angle-span*.5+span*i/steps
                verts.append((math.cos(t)*r,math.sin(t)*r,height))
    n=steps+1
    faces=[]
    for i in range(steps):
        faces.extend([(i,i+1,n+i+1,n+i),(2*n+i,3*n+i,3*n+i+1,2*n+i+1),
                      (i,2*n+i,2*n+i+1,i+1),(n+i,n+i+1,3*n+i+1,3*n+i)])
    faces.extend([(0,n,3*n,2*n),(n-1,2*n-1,4*n-1,3*n-1)])
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(verts,[],faces); mesh.update()
    ob=bpy.data.objects.new(name,mesh); collection.objects.link(ob); ob.data.materials.append(M[mat]); objects.append(ob)
    bevel=ob.modifiers.new("Edge treatment","BEVEL"); bevel.width=.025; bevel.segments=2
    return ob

# The public plaza is a layered, radial surface, rather than a flat primitive.
cylinder("Floating civic deck",(0,0,-.64),24.4,1.1,"black",128)
cylinder("Machined deck lip",(0,0,-.13),24.0,.22,"edge",128)
cylinder("Walkable ceramic field",(0,0,-.045),23.7,.12,"ground",128)
for r in (8.2,15.0,23.1):
    torus("Radial inlay %.1f"%r,(0,0,.025),r,.035,"cyan")
for i in range(24):
    t=i*math.tau/24
    ring_segment("Radial deck panel",19.1,t,.24,.025,.028,"hull",7.1)
    if i%2==0:
        cube("Dock edge beacon",(24*math.cos(t),24*math.sin(t),.3),(.4,.7,.28),"cyan",.08,t)
for y in (-17,-14,-11,-8):
    cube("Approach centerline",(0,y,.055),(.13,1.45,.025),"cyan",.01)
for x in (-5.4,5.4):
    cube("Portal approach runway",(x,-10,.04),(.08,10,.025),"cyan",.01)
for i in range(8):
    x=-21+i*6
    cube("Outer ground expansion seam",(x,0,.045),(.035,43,.02),"black",0)

# Central four-metre portal: layered titanium rings, segmented capacitors and pylons.
portal_z=4.55
rotation=(math.pi/2,0,0)
torus("Portal outer titanium housing",(0,0,portal_z),4.15,.32,"hull",rotation)
torus("Portal bright inner aperture",(0,-.24,portal_z),3.78,.09,"cyan",rotation)
torus("Portal rear violet circuit",(0,.25,portal_z),4.23,.055,"blue",rotation)
for i in range(24):
    a=i*math.tau/24
    x=4.18*math.sin(a); z=portal_z+4.18*math.cos(a)
    ob=cube("Portal radial capacitor %02d"%i,(x,0,z),(.42,.77,.47),"edge",.06)
    ob.rotation_euler[1]=a
    if i%3==0:
        ob=cube("Aperture charge cell",(x,-.435,z),(.19,.035,.33),"cyan",.015)
        ob.rotation_euler[1]=a
for side in (-1,1):
    cube("Portal supporting buttress",(side*4.9,.5,1.7),(1.05,2.4,3.4),"hull",.2)
    beam("Diagonal portal anchorage",(side*5.0,.65,1.9),(side*3.55,.4,4.0),.5,"edge",.65)
    cube("Portal vertical status lamp",(side*4.9,-.73,1.8),(.16,.04,2.2),"cyan",.02)
    cylinder("Portal pressure foot",(side*4.9,.5,.2),1.0,.4,"edge",12)
cube("Portal podium",(0,.3,.13),(9.4,3.3,.26),"hull",.15)

# Right-hand spacecraft service pad and a clearly readable in-world terminal.
pad=(15,-6)
cylinder("Hangar elevated octagonal pad",(*pad,.13),6.7,.25,"hull",12)
torus("Pad docking ring",(*pad,.275),5.7,.06,"amber")
for i in range(12):
    a=i*math.tau/12
    ob=cube("Pad segmented threshold",(pad[0]+6.0*math.cos(a),pad[1]+6.0*math.sin(a),.29),(1.2,.18,.04),"amber",.02,a+math.pi/2)
for x in (12,18):
    cube("Landing H upright",(x,-6,.29),(.18,4,.02),"white",.01)
cube("Landing H crossbar",(15,-6,.29),(6,.18,.02),"white",.01)
cube("Hangar terminal base",(10.2,-10,.5),(1.4,1.15,1.0),"edge",.15)
beam("Hangar terminal pedestal",(10.2,-10,.8),(10.2,-10.2,1.65),.3,"hull",.35)
console=cube("Hangar angled touch display",(10.2,-10.1,1.6),(1.45,.12,.75),"black",.08)
console.rotation_euler[0]=math.radians(18)
for i in range(4):
    cube("Console screen readout",(9.8+i*.25,-10.18,1.68),(.1,.025,.25+(.1 if i%2 else 0)),"cyan",.01)

# Original display spacecraft: angular porcelain fuselage, swept foils, dark canopy.
def hull(name,loc,scale,mat):
    verts=[(0,-3.5,.3),(-.65,-1,.1),(-.7,2,.15),(0,2.55,.25),(.7,2,.15),(.65,-1,.1),
           (0,-2.8,.7),(-.5,-.6,.9),(-.4,1.6,.75),(.4,1.6,.75),(.5,-.6,.9)]
    faces=[(0,1,2,3,4,5),(0,6,7,1),(1,7,8,2),(2,8,9,3),(3,9,10,4),(4,10,6,5),(6,10,7),(7,10,9,8)]
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(verts,[],faces); mesh.update()
    ob=bpy.data.objects.new(name,mesh); collection.objects.link(ob); ob.location=loc; ob.scale=scale
    ob.data.materials.append(M[mat]); objects.append(ob)
    mod=ob.modifiers.new("Spaceframe bevel","BEVEL"); mod.width=.085; mod.segments=3
    return ob
hull("Whitefalcon display spacecraft",(15,-6,1.05),(1,1,1),"white")
canopy=cube("Black sapphire cockpit",(15,-6.5,2.06),(.7,1.6,.35),"glass",.14)
for side in (-1,1):
    fin=cube("Swept titanium wing",(15+side*1.35,-5.2,1.35),(2.2,2.1,.17),"edge",.1,side*.48)
    cube("Wingtip ion seam",(15+side*2.15,-5.15,1.49),(.12,1.6,.06),"cyan",.03,side*.48)
    cylinder("Engine ceramic pod",(15+side*.85,-4.4,1.4),.32,1.8,"hull",24,(math.pi/2,0,0))
    cylinder("Engine plasma iris",(15+side*.85,-3.46,1.4),.22,.05,"cyan",32,(math.pi/2,0,0))
    beam("Landing strut",(15+side*.75,-4.8,1.3),(15+side*1.1,-4.8,.38),.12,"edge")

# Monumental skyline: four distinct architectural families with real silhouettes.
def tower(index,x,y,width,depth,height,kind):
    prefix="T%02d_"%index
    cube(prefix+"foundation",(x,y,.4),(width+1.4,depth+1.4,.8),"black",.18)
    if kind==0: # Tapered glass spine / carved crown.
        cube(prefix+"main_core",(x,y,height*.46),(width,depth,height*.88),"hull",.4)
        cube(prefix+"glass_inset",(x,y-depth*.51,height*.48),(width*.8,.1,height*.8),"glass",.025)
        cube(prefix+"offset_crown",(x+width*.14,y,height*.94),(width*.68,depth*.85,height*.13),"edge",.22)
        beam(prefix+"mast",(x,y,height),(x,y,height+6),.11,"cyan")
    elif kind==1: # Twin structural fins with a suspended connecting core.
        for side in (-1,1):
            cube(prefix+"structural_fin",(x+side*width*.38,y,height*.5),(width*.22,depth,height),"edge",.2)
        cube(prefix+"hanging_glass_volume",(x,y,height*.6),(width*.56,depth*.9,height*.6),"glass",.3)
        cube(prefix+"top_cantilever",(x,y,height*.99),(width*1.1,depth*1.1,1.0),"hull",.18)
    elif kind==2: # Stepped communications arcology.
        for k in range(3):
            h=height*(1-.22*k); w=width*(1-.2*k)
            cube(prefix+"stepped_volume",(x,y+k*.65,h*.5),(w,depth*(1-.16*k),h),"hull" if k!=1 else "glass",.3)
        for k in range(3):
            torus(prefix+"sky_crown",(x,y+1,height+1+k*.65),width*.35,.06,"cyan" if k==1 else "edge",segments=48)
    else: # Rounded vertical data tower and satellite crown.
        cylinder(prefix+"octagonal_shaft",(x,y,height*.5),width*.52,height,"hull",12)
        for k in range(5):
            cylinder(prefix+"floating_ribbon",(x,y,height*(.28+k*.14)),width*.63,.35,"edge",12)
        torus(prefix+"aerial_crown",(x,y,height+1),width*.44,.1,"blue",segments=48)
    # Front panel divisions and lit office stripes avoid featureless cubes.
    for k in range(2,int(height/2.4)):
        z=k*2.4
        cube(prefix+"horizontal_mullion",(x,y-depth*.51-.04,z),(width*.83,.12,.055),"edge",.015)
        if k%3!=0:
            for side in (-1,1):
                cube(prefix+"inhabited_window",(x+side*width*.24,y-depth*.52-.08,z+.4),(width*.16,.04,.32),"window",.01)
    for side in (-1,1):
        cube(prefix+"vertical_light_rail",(x+side*width*.46,y-depth*.52,height*.46),(.065,.06,height*.7),"cyan" if index%4 else "blue",.015)
    if height>35:
        cube(prefix+"service_balcony",(x,y-depth*.65,height*.3),(width*1.25,depth*.4,.38),"edge",.15)
    # Geometric signage, readable as architecture rather than tiny text.
    if index%3==0:
        z=height*.54
        cube(prefix+"hologram_stem",(x-width*.68,y-depth*.6,z),(.12,.12,5.2),"amber",.025)
        for k in range(4):
            cube(prefix+"hologram_glyph",(x-width*.62+.35*k,y-depth*.6,z+1.6-k*.9),(.7,.1,.14),"amber",.025)

layout=[(-31,3,9,8,30,0),(-34,20,10,8,46,1),(-25,36,8,8,35,2),
        (-12,42,8,7,53,0),(3,48,10,9,64,1),(19,39,9,7,44,2),(31,22,10,8,38,3),
        (36,2,9,10,30,1),(-43,45,8,9,60,3),(43,46,11,8,61,0),
        (-31,68,12,10,70,2),(-10,75,10,8,83,3),(16,75,12,10,76,1),
        (42,75,11,10,68,0),(-60,34,11,12,63,1),(59,30,10,11,57,2)]
for index,row in enumerate(layout): tower(index,*row)

# A suspended multi-level boulevard ties the buildings into a continuous city.
cube("Skybridge main deck",(0,24,11),(56,4.3,.8),"hull",.16)
cube("Skybridge underside light",(0,21.8,10.7),(53,.08,.09),"cyan",.01)
for y in (21.9,26.1):
    cube("Bridge safety parapet",(0,y,12.05),(56,.18,1.25),"glass",.04)
    cube("Bridge floating handrail",(0,y,12.76),(56,.12,.1),"cyan",.025)
for x in (-24,-12,12,24):
    beam("Bridge diagonal brace",(x,24,1),(x+5,24,10.6),.45,"edge",.65)
for x in (-24,24):
    cube("Lift shaft",(x,24,5.4),(2.2,2.2,10.8),"glass",.14)
    cube("Lift strip",(x,22.85,5.4),(.14,.1,10),"amber",.02)

# Civic street furniture: benches, cable conduits, docking lights and marker obelisks.
for side in (-1,1):
    for y in (-15,-5,8,16):
        x=side*20
        cube("Plaza light foundation",(x,y,.25),(.9,.9,.5),"edge",.12)
        cube("Slender plaza lantern",(x,y,2.1),(.14,.14,3.7),"hull",.035)
        cube("Lantern luminous cap",(x,y,3.7),(.35,.35,.7),"cyan",.05)
    for y in (-13,12):
        cube("Cantilever public bench",(side*13,y,.6),(3.6,1.0,.18),"white",.08)
        for dx in (-1.2,1.2):
            cube("Bench pedestal",(side*13+dx,y,.28),(.14,.5,.56),"edge",.03)
for x in (-9,9):
    cube("Substation base",(x,5,.7),(1.8,1.6,1.4),"hull",.16)
    for i in range(5):
        cube("Ventilation fin",(x-.6+i*.3,4.14,.8),(.07,.08,.7),"edge",.01)
    cube("Substation indicator",(x,4.12,1.24),(.9,.05,.08),"cyan",.015)

# Production lighting and camera are saved in the editable Blender source.
world=bpy.data.worlds.new("Neon blue atmosphere")
world.use_nodes=True
world.node_tree.nodes.get("Background").inputs[0].default_value=(.035,.06,.12,1)
world.node_tree.nodes.get("Background").inputs[1].default_value=.35
scene.world=world
def area(name,loc,color,power,size,target):
    data=bpy.data.lights.new(name,"AREA"); data.energy=power; data.color=color; data.shape="DISK"; data.size=size
    obj=bpy.data.objects.new(name,data); scene.collection.objects.link(obj); obj.location=loc
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat("-Z","Y").to_euler()
area("Moon softbox",(0,-20,40),(.34,.54,1),5000,25,(0,0,0))
area("Warm docking light",(18,-11,12),(1,.5,.2),1600,12,(15,-6,0))
area("Portal spill",(0,-3,6),(.1,.65,1),1000,8,(0,-7,0))
cam_data=bpy.data.cameras.new("City review lens"); cam=bpy.data.objects.new("City review camera",cam_data)
scene.collection.objects.link(cam); cam.location=(33,-45,30)
cam.rotation_euler=(Vector((0,8,8))-cam.location).to_track_quat("-Z","Y").to_euler()
cam_data.lens=33; scene.camera=cam
try: scene.render.engine="CYCLES"
except TypeError: pass
if hasattr(scene,"cycles"):
    scene.cycles.samples=24; scene.cycles.use_denoising=True
scene.render.resolution_x=1600; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.view_settings.view_transform="AgX"

# Preserve all editable, named source objects. Export evaluated copies batched by material.
export_col=bpy.data.collections.new("CITY_Export_Batches")
scene.collection.children.link(export_col)
batches={}
deps=bpy.context.evaluated_depsgraph_get()
for ob in objects:
    evaluated=ob.evaluated_get(deps)
    mesh=bpy.data.meshes.new_from_object(evaluated, depsgraph=deps)
    copy=bpy.data.objects.new("EXPORT_"+ob.name,mesh); export_col.objects.link(copy)
    copy.matrix_world=ob.matrix_world.copy()
    mat=ob.data.materials[0]
    batches.setdefault(mat.name,[]).append(copy)
for mat_name,group in batches.items():
    bpy.ops.object.select_all(action="DESELECT")
    for ob in group: ob.select_set(True)
    bpy.context.view_layer.objects.active=group[0]
    bpy.ops.object.join()
    group[0].name="CityBatch_"+mat_name.split(" · ")[0]
bpy.ops.object.select_all(action="DESELECT")
export_objects=list(export_col.objects)
for ob in export_objects: ob.select_set(True)
bpy.context.view_layer.objects.active=export_objects[0]
bpy.ops.export_scene.gltf(filepath=str(OUT/"neon_city.glb"),export_format="GLB",use_selection=True,
    export_apply=True,export_cameras=False,export_lights=False,export_extras=True)
export_col.hide_viewport=True; export_col.hide_render=True
bpy.ops.object.select_all(action="DESELECT")
# Saving a copy keeps the current session's original filepath intact.
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/"neon_city.blend"),copy=True)
manifest={"author":"BeatDrift original procedural Blender architecture", "blender":bpy.app.version_string,
          "editable_meshes":len(objects),"export_meshes":len(export_objects),
          "vertices":sum(len(o.data.vertices) for o in export_objects),
          "triangles":sum(len(p.vertices)-2 for o in export_objects for p in o.data.polygons),
          "portal_world":[0,4.55,0],"hangar_terminal_world":[10.2,0,10.0],
          "generator":"tools/build_neon_city.py","external_assets":[],"seed":4219}
(SOURCE/"manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding="utf-8")
print("BEATDRIFT_CITY_BUILT",json.dumps(manifest,ensure_ascii=False))
