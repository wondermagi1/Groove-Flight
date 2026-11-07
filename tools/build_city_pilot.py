"""Original humanoid pilot with a rigid-part skeletal rig and exported walk cycle."""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/city'
SOURCE = ROOT / 'source_art/city'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)
scene = bpy.data.scenes.new('GROOVE_FLIGHT_Original_Pilot')
bpy.context.window.scene = scene
meshes = []

def mat(name, color, metal=0.0, glow=0.0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Metallic'].default_value = metal
    p.inputs['Roughness'].default_value = .36
    p.inputs['Emission Color'].default_value = (*color, 1)
    p.inputs['Emission Strength'].default_value = glow
    return m

M = {'suit': mat('Pilot navy pressure fabric', (.035,.075,.13)),
     'white': mat('Pilot porcelain armour', (.67,.80,.88), .45),
     'dark': mat('Pilot articulated graphite joints', (.012,.022,.04), .25),
     'visor': mat('Pilot deep sapphire visor', (.018,.09,.16), .82),
     'cyan': mat('Pilot cyan status seams', (.02,.67,1), .2, 2.0),
     'face': mat('Pilot visible warm face', (.57,.35,.22)),
     'hair': mat('Pilot dark brown hair', (.045,.026,.02)),
     'amber': mat('Pilot amber flight scarf', (.85,.27,.055))}

def finish(obj, name, material, bone):
    obj.name = name
    obj.data.materials.append(M[material])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    meshes.append((obj,bone))
    return obj

def ellipsoid(name, loc, scale, material, bone):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=1, location=loc)
    ob=bpy.context.object; ob.scale=scale
    for f in ob.data.polygons: f.use_smooth=True
    return finish(ob,name,material,bone)

def block(name, loc, size, material, bone, bevel=.04):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    ob=bpy.context.object; ob.dimensions=size
    finish(ob,name,material,bone)
    mod=ob.modifiers.new('Tailored shell bevel','BEVEL'); mod.width=bevel; mod.segments=3
    return ob

def limb(name,a,b,r,material,bone):
    a=Vector(a); b=Vector(b)
    ob=ellipsoid(name,(a+b)*.5,(r,r,(b-a).length*.58),material,bone)
    ob.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return ob

# Forward is Blender -Y; glTF converts that to Godot +Z.
ellipsoid('Flight jacket torso',(0,0,1.23),(.27,.16,.35),'suit','spine')
block('Breast plate',(0,-.145,1.34),(.40,.08,.31),'white','spine',.06)
block('Chest cyan instrument',(0,-.196,1.37),(.13,.025,.065),'cyan','spine',.01)
block('Chest flight recorder',(0,-.215,1.42),(.12,.026,.07),'dark','spine',.008)
block('Chest amber status',(0,-.232,1.435),(.073,.012,.025),'amber','spine',.004)
for side,suffix in ((-1,'L'),(1,'R')):
    block('Flight harness '+suffix,(side*.115,-.205,1.22),(.036,.032,.34),'white','spine',.008)
block('Dorsal power core',(0,.205,1.28),(.25,.115,.30),'dark','spine',.025)
block('Dorsal core light',(0,.269,1.29),(.075,.018,.18),'cyan','spine',.008)
block('Helmet crest',(0,-.015,2.02),(.040,.23,.13),'white','head',.012)
block('Helmet crest light',(0,-.025,2.075),(.048,.16,.025),'cyan','head',.006)
block('Comm antenna',(-.185,.02,2.00),(.024,.024,.27),'dark','head',.005)
block('Comm antenna tip',(-.205,.02,2.13),(.048,.048,.038),'amber','head',.008)
for side in (-1,1):
    block('Shoulder beacon',(side*.305,-.04,1.50),(.052,.052,.085),'cyan','spine',.012)
block('Waist utility belt',(0,0,.96),(.46,.34,.10),'dark','root')
for side in (-1,1):
    block('Belt field pouch',(side*.25,-.035,.92),(.10,.16,.17),'white','root')
ellipsoid('Neck seal',(0,0,1.58),(.105,.10,.105),'dark','spine')
ellipsoid('Warm human face',(0,-.045,1.79),(.155,.132,.185),'face','head')
ellipsoid('Helmet top shell',(0,.015,1.87),(.184,.16,.151),'white','head')
for side in (-1,1):
    ellipsoid('Helmet ear module',(side*.16,0,1.80),(.043,.096,.105),'dark','head')
    block('Helmet cyan communication light',(side*.195,-.012,1.80),(.018,.06,.035),'cyan','head',.008)
    block('Human dark eyes',(side*.060,-.170,1.81),(.036,.017,.018),'hair','head',.008)
block('Orange flight scarf collar',(0,-.03,1.565),(.29,.30,.075),'amber','spine')
block('Scarf tail',(0,.14,1.38),(.12,.025,.34),'amber','spine',.018)
for side,suffix in ((-1,'L'),(1,'R')):
    shoulder=(side*.30,0,1.48); elbow=(side*.37,-.015,1.17); wrist=(side*.36,-.055,.96)
    ellipsoid('Shoulder ceramic cap '+suffix,shoulder,(.14,.17,.14),'white','arm_'+suffix)
    limb('Upper sleeve '+suffix,shoulder,elbow,.095,'suit','arm_'+suffix)
    ellipsoid('Elbow flex joint '+suffix,elbow,(.085,.085,.085),'dark','forearm_'+suffix)
    limb('Forearm shell '+suffix,elbow,wrist,.09,'white','forearm_'+suffix)
    ellipsoid('Flight glove '+suffix,(side*.36,-.055,.92),(.082,.072,.095),'dark','forearm_'+suffix)
    hip=(side*.13,0,.94); knee=(side*.14,0,.56); ankle=(side*.14,0,.14)
    limb('Pressure trousers thigh '+suffix,hip,knee,.125,'suit','thigh_'+suffix)
    ellipsoid('Articulated knee plate '+suffix,(side*.14,-.09,.55),(.09,.07,.10),'white','shin_'+suffix)
    limb('Armoured shin '+suffix,knee,ankle,.10,'suit','shin_'+suffix)
    block('Ceramic shin stripe '+suffix,(side*.14,-.09,.32),(.12,.05,.22),'white','shin_'+suffix,.022)
    block('Magnetic flight boot '+suffix,(side*.14,-.065,.09),(.22,.36,.18),'dark','shin_'+suffix,.04)

# Named bones and weights let the engine animate actual limbs rather than wobbling the body.
arm=bpy.data.armatures.new('Pilot humanoid skeleton')
rig=bpy.data.objects.new('PilotRig',arm); scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active=rig; rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
specs=[('root',(0,0,.9),(0,0,1.02),None),('spine',(0,0,1.02),(0,0,1.57),'root'),('head',(0,0,1.57),(0,0,1.99),'spine')]
for side,suffix in ((-1,'L'),(1,'R')):
    specs.extend([('arm_'+suffix,(side*.30,0,1.48),(side*.37,-.015,1.17),'spine'),
                  ('forearm_'+suffix,(side*.37,-.015,1.17),(side*.36,-.055,.96),'arm_'+suffix),
                  ('thigh_'+suffix,(side*.13,0,.94),(side*.14,0,.56),'root'),
                  ('shin_'+suffix,(side*.14,0,.56),(side*.14,0,.14),'thigh_'+suffix)])
for name,head,tail,parent in specs:
    b=arm.edit_bones.new(name); b.head=head; b.tail=tail
    if parent: b.parent=arm.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
for ob,bone in meshes:
    vg=ob.vertex_groups.new(name=bone); vg.add(list(range(len(ob.data.vertices))),1,'REPLACE')
    modifier=ob.modifiers.new('Humanoid skeletal deformation','ARMATURE'); modifier.object=rig
    ob.parent=rig
for b in rig.pose.bones: b.rotation_mode='XYZ'
scene.render.fps=24
for frame in range(1,26):
    t=(frame-1)/24*math.tau
    for side,suffix in ((-1,'L'),(1,'R')):
        phase=t+(math.pi if side==1 else 0)
        rig.pose.bones['thigh_'+suffix].rotation_euler.x=math.sin(phase)*.49
        rig.pose.bones['shin_'+suffix].rotation_euler.x=max(0,-math.sin(phase))*.58
        rig.pose.bones['arm_'+suffix].rotation_euler.x=-math.sin(phase)*.30
        rig.pose.bones['forearm_'+suffix].rotation_euler.x=.12+max(0,math.sin(phase))*.10
    for b in rig.pose.bones: b.keyframe_insert('rotation_euler',frame=frame,group=b.name)
walk=rig.animation_data.action; walk.name='Walk'
rig.animation_data.action=None
for b in rig.pose.bones: b.rotation_euler=(0,0,0)
for frame in (1,25,49):
    rig.pose.bones['spine'].rotation_euler.x=.012 if frame==25 else 0
    for b in rig.pose.bones: b.keyframe_insert('rotation_euler',frame=frame,group=b.name)
idle=rig.animation_data.action; idle.name='Idle'
rig.animation_data.action=None
for action in (walk,idle):
    track=rig.animation_data.nla_tracks.new(); track.name=action.name
    track.strips.new(action.name,1,action)
scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
for ob,_ in meshes: ob.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'pilot.glb'),export_format='GLB',use_selection=True,
    export_apply=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_skins=True)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'pilot.blend'),copy=True)
print('GROOVE_FLIGHT_PILOT_BUILT',json.dumps({'parts':len(meshes),'bones':len(specs),'animations':['Walk','Idle']}),flush=True)
