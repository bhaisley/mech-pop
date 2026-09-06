"""Original MECH POP hard-surface model factory, Blender 4.5 LTS.

Authoring coordinates are the Godot contract: X right, Y up, Z toward camera.
The conversion into Blender Z-up is isolated in g(). Models export back Y-up.
Each named pivot is an animation/socket contract, independent of mesh topology.
"""
import argparse
import math
import sys
from pathlib import Path
import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'art_source/models'
EXPORT = ROOT / 'characters/models'
MODULES = ROOT / 'modules/models'
for folder in (ART, EXPORT, MODULES):
    folder.mkdir(parents=True, exist_ok=True)

PALETTES = {
    'nova': dict(color='2875EF', pale='EFF6FF', dark='14428B', energy='54E8FF', accent='A9DFFF'),
    'kuren': dict(color='E73A51', pale='FF7876', dark='852A44', energy='FFB455', accent='FFEAC9'),
    'terra': dict(color='738B40', pale='B2C57B', dark='3D5030', energy='C7EB53', accent='F1E9B5'),
    'momo': dict(color='F48DCB', pale='FFF0F8', dark='A34484', energy='FFDDF6', accent='A1F2F3'),
    'shadow': dict(color='494063', pale='9E84BD', dark='292738', energy='DF74FF', accent='F0B0FF'),
    'lumi': dict(color='EEC460', pale='FFF8E7', dark='90733E', energy='ACEEFF', accent='FFE8A1'),
    'kai': dict(color='328ADC', pale='D6EEFF', dark='24476C', energy='78E9FF', accent='B9F8FF'),
    'zero': dict(color='474551', pale='ACABB7', dark='2B2936', energy='FF5C77', accent='FFBAC3'),
}
MATERIALS = {}

def linear(c):
    return c/12.92 if c <= 0.04045 else ((c+0.055)/1.055)**2.4

def material(name, hexcolor, glow=False):
    if name in MATERIALS:
        return MATERIALS[name]
    rgb = tuple(linear(int(hexcolor[i:i+2],16)/255) for i in (0,2,4))
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*rgb, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*rgb, 1)
    shader.inputs['Roughness'].default_value = 0.52
    shader.inputs['Metallic'].default_value = 0.1
    if glow:
        shader.inputs['Emission Color'].default_value = (*rgb,1)
        shader.inputs['Emission Strength'].default_value = 1.0
    mat['mech_pop_glow'] = glow
    MATERIALS[name] = mat
    return mat

def palette(chassis):
    result = {k:material(chassis+'_'+k, value, k in ('energy','accent')) for k,value in PALETTES[chassis].items()}
    result['ink'] = material('shared_ink','101C2E')
    result['joint'] = material('shared_joint','2E4158')
    result['steel'] = material('shared_steel','A2B5CC')
    result['white'] = material('shared_white','F2F8FF')
    result['eye_glint'] = material('glow_eye_glint','FFFFFF',True)
    return result

def g(point):
    return (point[0], -point[2], point[1])

def empty(name, parent=None, at=(0,0,0)):
    obj = bpy.data.objects.new(name,None)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    obj.location = g(at)
    return obj

def finish(obj, name, parent, mat, bevel=0.0, smooth=False):
    obj.name = name
    obj.parent = parent
    if mat:
        obj.data.materials.append(mat)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = obj.modifiers.new('Machined edge bevel','BEVEL')
        modifier.width = bevel
        modifier.segments = 2
        modifier.affect = 'EDGES'
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        normal = obj.modifiers.new('Weighted armor normals','WEIGHTED_NORMAL')
        normal.keep_sharp = True
        normal.weight = 50
        bpy.ops.object.modifier_apply(modifier=normal.name)
    for poly in obj.data.polygons:
        poly.use_smooth = smooth
    obj.select_set(False)
    return obj

def box(name, parent, at, size, mat, bevel=.035, angle=0):
    bpy.ops.object.select_all(action='DESELECT')
    bpy.ops.mesh.primitive_cube_add(size=1, location=g(at))
    obj = bpy.context.object
    obj.dimensions = (size[0],size[2],size[1])
    obj.rotation_euler[1] = -angle
    return finish(obj,name,parent,mat,bevel)

def ellipsoid(name,parent,at,size,mat,segments=24,rings=12):
    bpy.ops.object.select_all(action='DESELECT')
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings, radius=1,location=g(at))
    obj=bpy.context.object
    obj.scale=(size[0]*.5,size[2]*.5,size[1]*.5)
    return finish(obj,name,parent,mat,smooth=True)

def cylinder(name,parent,at,radius,depth,mat,axis='z',vertices=16,bevel=.015):
    bpy.ops.object.select_all(action='DESELECT')
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=g(at))
    obj=bpy.context.object
    if axis=='x': obj.rotation_euler[1]=math.pi/2
    elif axis=='z': obj.rotation_euler[0]=math.pi/2
    return finish(obj,name,parent,mat,bevel)

def plate(name,parent,points,z,depth,mat,bevel=.025):
    """Beveled extrusion of an intentionally authored XY silhouette."""
    vertices=[g((x,y,z)) for x,y in points]+[g((x,y,z-depth)) for x,y in points]
    n=len(points)
    faces=[tuple(range(n)),tuple(reversed(range(n,2*n)))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(vertices,[],faces)
    mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(mesh);bm.free()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action='DESELECT')
    return finish(obj,name,parent,mat,bevel)

def diamond(name,parent,at,width,height,depth,mat):
    x,y,z=at
    return plate(name,parent,[(x,y+height/2),(x+width/2,y),(x,y-height/2),(x-width/2,y)],z,depth,mat,.009)

def line(name,parent,a,b,radius,mat):
    midpoint=(Vector(g(a))+Vector(g(b)))*.5
    direction=Vector(g(b))-Vector(g(a))
    bpy.ops.object.select_all(action='DESELECT')
    bpy.ops.mesh.primitive_cylinder_add(vertices=8,radius=radius,depth=direction.length,location=midpoint)
    obj=bpy.context.object
    obj.rotation_euler=direction.to_track_quat('Z','Y').to_euler()
    return finish(obj,name,parent,mat)

def torus(name,parent,at,radius,tube,mat,axis='z'):
    bpy.ops.object.select_all(action='DESELECT')
    bpy.ops.mesh.primitive_torus_add(major_segments=32,minor_segments=8,major_radius=radius,minor_radius=tube,location=g(at))
    obj=bpy.context.object
    if axis=='z': obj.rotation_euler[0]=math.pi/2
    elif axis=='x': obj.rotation_euler[1]=math.pi/2
    return finish(obj,name,parent,mat,smooth=True)

def mirror_profile(points,side):
    return [(x*side,y) for x,y in points]

def bolt(parent,at,p,radius=.035):
    cylinder('Recess',parent,at,radius*1.4,.012,p['ink'])
    cylinder('Hex fastener',parent,(at[0],at[1],at[2]+.009),radius,.019,p['steel'],vertices=6,bevel=.003)

def build_nova():
    p=palette('nova')
    root=empty('Rig')
    torso=empty('Torso',root,(0,1.12,0))
    box('Core cradle',torso,(0,0,0),(.69,.62,.50),p['ink'],.08)
    box('Belly actuator',torso,(0,-.30,.04),(.37,.24,.30),p['joint'],.04)
    for side in (-1,1):
        line('Core cage',torso,(side*.22,-.24,.29),(side*.29,.20,.26),.055,p['steel'])
        cylinder('Core bracket',torso,(side*.24,.10,.33),.065,.05,p['color'],vertices=10)
    core=diamond('Core',torso,(0,.05,.37),.29,.39,.12,p['energy'])
    for i in range(3): box('Belly vent',torso,(0,-.20-i*.057,.285),(.23,.025,.025),p['steel'],.008)
    hips=empty('Hips',root,(0,.74,0))
    box('Hip transmission',hips,(0,0,0),(.63,.25,.38),p['ink'],.05)
    plate('Belt buckle',hips,[(-.22,.08),(.22,.08),(.15,-.11),(0,-.18),(-.15,-.11)],.29,.13,p['white'])
    diamond('Belt jewel',hips,(0,-.005,.302),.13,.17,.02,p['color'])
    for side in (-1,1):
        plate('Hip skirt',hips,mirror_profile([(.18,.03),(.40,.02),(.45,-.23),(.21,-.20)],side),.12,.34,p['color'])
    head=empty('Head',root,(0,1.92,.015))
    ellipsoid('Helmet backing',head,(0,.14,-.10),(1.32,1.08,.96),p['white'])
    ellipsoid('Visor seal',head,(0,-.085,.325),(1.17,.77,.37),p['joint'])
    ellipsoid('Midnight visor',head,(0,-.09,.402),(1.08,.68,.25),p['ink'])
    plate('Crown armor',head,[(-.61,.15),(-.46,.52),(0,.67),(.46,.52),(.61,.15),(.40,.04),(0,-.20),(-.40,.04)],.50,.25,p['white'],.04)
    plate('Crown ridge',head,[(-.16,.51),(0,.67),(.16,.51),(.095,.13),(0,.02),(-.095,.13)],.548,.05,p['white'],.015)
    diamond('Forehead inset',head,(0,.32,.575),.19,.31,.035,p['color'])
    diamond('Forehead glint',head,(0,.34,.595),.095,.19,.018,p['energy'])
    for side in (-1,1):
        eye=ellipsoid('EyeLeft' if side<0 else 'EyeRight',head,(side*.24,-.10,.531),(.285,.39,.055),p['energy'])
        eye.rotation_euler[1]=-side*.40
        ellipsoid('Eye glint',head,(side*.24-.038,-.025,.563),(.064,.083,.025),p['eye_glint'],16,8)
        plate('Cobalt cheek',head,mirror_profile([(.40,.045),(.60,.16),(.62,-.19),(.35,-.39),(.19,-.39)],side),.427,.18,p['color'],.025)
        plate('White jaw plate',head,mirror_profile([(.48,-.24),(.36,-.40),(.09,-.42),(.19,-.33)],side),.46,.08,p['white'],.015)
        plate('Crescent fin',head,mirror_profile([(.46,.08),(.70,.20),(.84,.79),(.77,1.0),(.41,.61)],side),.18,.25,p['color'],.025)
        plate('Fin white inset',head,mirror_profile([(.53,.13),(.68,.24),(.73,.54),(.59,.41)],side),.213,.035,p['white'],.013)
        cylinder('Ear housing',head,(side*.66,.065,.03),.245,.25,p['color'],axis='x',vertices=20)
        cylinder('Ear cap',head,(side*.805,.065,.03),.184,.065,p['white'],axis='x',vertices=20)
        cylinder('Ear bearing',head,(side*.844,.065,.03),.117,.015,p['ink'],axis='x',vertices=20)
        cylinder('Ear light',head,(side*.856,.065,.03),.067,.017,p['energy'],axis='x',vertices=16)
        bolt(head,(side*.49,.10,.49),p,.025)
    plate('Chin point',head,[(-.11,-.39),(0,-.44),(.11,-.39),(0,-.35)],.49,.09,p['steel'],.012)
    _limbs(root,p,'nova')
    cylinder('Permanent right shoulder',root,(.56,1.29,0),.16,.29,p['joint'],axis='x')
    box('Permanent right upper arm',root,(.57,1.17,0),(.22,.28,.26),p['ink'],.03)
    cylinder('Exposed wrist coupler',root,(.59,1.02,.07),.145,.19,p['steel'],axis='x')
    cylinder('Empty connector ring',root,(.695,1.02,.07),.102,.025,p['energy'],axis='x')
    cylinder('Empty connector bore',root,(.711,1.02,.07),.066,.016,p['ink'],axis='x')
    empty('WeaponSocket',root,(.61,1.02,.07))
    empty('ShellSocket',root,(0,1.12,0))
    root['author_height']=2.92
    root['chassis']='nova'
    return root

def _limbs(root,p,chassis):
    # Permanent left arm gives every chassis real attack silhouettes after arm loss.
    left=empty('LeftArm',root,(-.57,1.34,0))
    cylinder('Shoulder bearing',left,(0,-.035,0),.17,.36,p['joint'],axis='x')
    box('Upper arm',left,(0,-.18,0),(.23,.31,.29),p['ink'],.04)
    cylinder('Elbow',left,(0,-.33,.04),.14,.31,p['steel'],axis='z')
    box('Wrist block',left,(0,-.47,.07),(.32,.34,.36),p['color'],.045)
    plate('Wrist armor',left,[(-.17,-.35),(.13,-.35),(.19,-.56),(.04,-.66),(-.16,-.56)],.28,.14,p['white'] if chassis=='nova' else p['pale'])
    diamond('Wrist light',left,(0,-.44,.298),.07,.14,.025,p['energy'])
    box('Palm',left,(0,-.70,.11),(.25,.22,.29),p['ink'],.035)
    for i in range(3):
        box('Finger',left,(-.079+i*.077,-.75,.254),(.064,.16,.065),p['joint'],.015)
    for side in (-1,1):
        leg=empty('LeftLeg' if side<0 else 'RightLeg',root,(side*.27,.72,0))
        cylinder('Hip bearing',leg,(0,-.015,0),.14,.28,p['joint'],axis='x')
        box('Thigh piston',leg,(0,-.17,0),(.23,.29,.29),p['ink'],.035)
        plate('Thigh plate',leg,[(-.16,-.06),(.15,-.06),(.16,-.28),(0,-.32),(-.16,-.26)],.22,.13,p['white'] if chassis=='nova' else p['color'])
        cylinder('Knee bearing',leg,(0,-.34,0),.14,.34,p['joint'],axis='x')
        diamond('Knee armor',leg,(0,-.34,.265),.28,.25,.12,p['color'])
        box('Shin actuator',leg,(0,-.49,0),(.23,.24,.31),p['ink'],.035)
        plate('Shin guard',leg,[(-.16,-.40),(.15,-.40),(.20,-.65),(-.21,-.65)],.255,.22,p['white'] if chassis=='nova' else p['pale'])
        box('Sole',leg,(0,-.66,.12),(.48,.14,.65),p['ink'],.035)
        box('Toe armor',leg,(0,-.59,.25),(.45,.21,.43),p['color'],.06)
        plate('Toe cap',leg,[(-.21,-.54),(.20,-.54),(.23,-.66),(-.23,-.66)],.482,.05,p['white'] if chassis=='nova' else p['pale'],.016)
        bolt(leg,(0,-.45,.27),p,.022)

def _core_body(root,p,chassis):
    torso=empty('Torso',root,(0,1.12,0))
    box('Core cradle',torso,(0,0,0),(.69,.62,.50),p['ink'],.08)
    box('Belly actuator',torso,(0,-.30,.04),(.37,.24,.30),p['joint'],.04)
    for side in (-1,1):
        line('Core cage',torso,(side*.22,-.24,.29),(side*.29,.20,.26),.055,p['steel'])
        cylinder('Core bracket',torso,(side*.24,.10,.33),.065,.05,p['color'],vertices=10)
    diamond('Core',torso,(0,.05,.37),.29,.39,.12,p['energy'])
    hips=empty('Hips',root,(0,.74,0))
    box('Hip transmission',hips,(0,0,0),(.63,.25,.38),p['ink'],.05)
    plate('Belt buckle',hips,[(-.22,.08),(.22,.08),(.15,-.11),(0,-.18),(-.15,-.11)],.29,.13,p['color'])
    diamond('Belt jewel',hips,(0,-.005,.302),.13,.17,.02,p['pale'])
    _limbs(root,p,chassis)
    cylinder('Permanent right shoulder',root,(.56,1.29,0),.16,.29,p['joint'],axis='x')
    box('Permanent right upper arm',root,(.57,1.17,0),(.22,.28,.26),p['ink'],.03)
    cylinder('Exposed wrist coupler',root,(.59,1.02,.07),.145,.19,p['steel'],axis='x')
    cylinder('Empty connector ring',root,(.695,1.02,.07),.102,.025,p['energy'],axis='x')
    cylinder('Empty connector bore',root,(.711,1.02,.07),.066,.016,p['ink'],axis='x')
    empty('WeaponSocket',root,(.61,1.02,.07))
    empty('ShellSocket',root,(0,1.12,0))
    return torso

def build_kuren():
    p=palette('kuren');root=empty('Rig');_core_body(root,p,'kuren')
    head=empty('Head',root,(0,1.89,.025))
    ellipsoid('Helmet lower shell',head,(0,.035,-.07),(1.31,.96,.96),p['dark'])
    ellipsoid('Dark angled visor',head,(0,-.05,.35),(1.13,.68,.35),p['ink'])
    plate('Speed crown',head,[(-.60,.12),(-.47,.51),(-.14,.62),(0,.45),(.15,.62),(.49,.47),(.61,.09),(.27,-.02),(0,-.21),(-.31,.025)],.51,.30,p['color'],.045)
    plate('Central heat vane',head,[(-.10,.37),(0,.82),(.15,.58),(.10,.02),(0,-.17),(-.085,.05)],.575,.12,p['color'],.025)
    diamond('Crown furnace',head,(0,.25,.706),.105,.23,.04,p['energy'])
    for side in (-1,1):
        eye=plate('EyeLeft' if side<0 else 'EyeRight',head,mirror_profile([(.075,-.14),(.45,.005),(.40,-.22),(.23,-.29)],side),.554,.03,p['energy'],.016)
        plate('Eye core',head,mirror_profile([(.12,-.16),(.40,-.055),(.34,-.16),(.21,-.22)],side),.591,.01,p['eye_glint'],.007)
        plate('Swept ear blade',head,mirror_profile([(.47,.06),(.94,.52),(.77,.67),(.52,.44)],side),.02,.30,p['color'],.025)
        plate('Blade ember inset',head,mirror_profile([(.64,.33),(.88,.52),(.77,.56)],side),.053,.04,p['pale'],.012)
        cylinder('Ear transmission',head,(side*.65,.02,-.02),.20,.25,p['ink'],axis='x')
        cylinder('Ear cap',head,(side*.80,.02,-.02),.135,.055,p['steel'],axis='x')
        cylinder('Ear heat light',head,(side*.835,.02,-.02),.078,.03,p['energy'],axis='x')
        plate('Cheek plate',head,mirror_profile([(.43,-.11),(.63,-.03),(.59,-.33),(.22,-.41),(.30,-.27)],side),.45,.15,p['color'])
        for i in range(2): box('Cheek gill',head,(side*(.39+i*.095),-.28+i*.04,.492),(.043,.13,.023),p['ink'],.007,angle=side*.32)
    plate('Angular chin',head,[(-.17,-.36),(0,-.45),(.17,-.36),(0,-.31)],.50,.13,p['pale'],.018)
    # Permanent ankle fins and a forward raked back drive distinguish the rushdown chassis.
    for child in list(root.children):
        if child.name in ('LeftLeg','RightLeg'):
            side=-1 if child.name=='LeftLeg' else 1
            plate('Ankle speed fin',child,mirror_profile([(.11,-.40),(.38,-.31),(.24,-.61),(.14,-.65)],side),-.08,.18,p['color'])
    box('Back drive',root,(0,1.20,-.38),(.48,.51,.27),p['dark'],.045)
    for side in (-1,1):
        cylinder('Afterburner',root,(side*.18,1.12,-.53),.11,.16,p['ink'],axis='z')
    root['author_height']=2.71;root['chassis']='kuren'
    return root

def build_terra():
    p=palette('terra');root=empty('Rig');torso=_core_body(root,p,'terra')
    torso.scale=(1.17,1.15,1.07)
    for child in root.children:
        if child.name=='LeftArm':
            child.scale=(1.38,1.3,1.10)
            child.location.x=-.68
            box('Clinch knuckle',child,(0,-.70,.20),(.41,.31,.29),p['color'],.055)
            for i in range(3): cylinder('Grip stud',child,(-.12+i*.12,-.70,.377),.04,.035,p['steel'],vertices=6)
        elif child.name in ('LeftLeg','RightLeg'):
            child.scale=(1.28,1.24,1.02)
            child.location.x*=1.22
    head=empty('Head',root,(0,1.90,-.005))
    box('Fortress helmet',head,(0,.08,-.06),(1.49,.98,.98),p['color'],.19)
    box('Visor gasket',head,(0,-.04,.437),(1.27,.60,.16),p['ink'],.14)
    box('Visor glass',head,(0,-.06,.53),(1.13,.47,.065),p['ink'],.11)
    plate('Heavy brow',head,[(-.72,.23),(-.58,.54),(.58,.54),(.73,.23),(.52,.12),(.18,.20),(0,.13),(-.18,.20),(-.52,.12)],.49,.22,p['color'],.05)
    plate('Brow highlight',head,[(-.56,.49),(.56,.49),(.62,.36),(-.62,.36)],.544,.045,p['pale'],.02)
    for side in (-1,1):
        eye=ellipsoid('EyeLeft' if side<0 else 'EyeRight',head,(side*.28,-.06,.584),(.29,.24,.047),p['energy'],20,10)
        eye.rotation_euler[1]=side*.11
        box('Eyebrow',head,(side*.28,.055,.603),(.32,.055,.025),p['dark'],.01,angle=side*.09)
        ellipsoid('Eye glint',head,(side*.28-.045,-.015,.617),(.055,.055,.018),p['eye_glint'],12,6)
        box('Cheek armor',head,(side*.58,-.23,.34),(.33,.39,.39),p['dark'],.065)
        plate('Cheek inset',head,mirror_profile([(.43,-.12),(.67,-.10),(.67,-.36),(.48,-.40)],side),.565,.07,p['color'],.025)
        cylinder('Headside hinge',head,(side*.76,.05,-.03),.22,.16,p['ink'],axis='x')
        cylinder('Headside cap',head,(side*.856,.05,-.03),.13,.055,p['pale'],axis='x',vertices=12)
        bolt(head,(side*.58,.27,.57),p,.029)
    # Asymmetric sensor mast and opposite armored nub survive shell loss.
    cylinder('Sensor stalk',head,(-.47,.68,-.08),.047,.36,p['joint'],axis='y')
    ellipsoid('Sensor beacon',head,(-.47,.88,-.08),(.14,.19,.14),p['energy'],16,8)
    box('Protected telemetry',head,(.47,.60,-.10),(.27,.28,.28),p['dark'],.04)
    box('Telemetry strip',head,(.47,.70,.05),(.16,.07,.04),p['energy'],.008)
    plate('Jaw plow',head,[(-.36,-.29),(.36,-.29),(.30,-.46),(-.30,-.46)],.515,.20,p['pale'],.045)
    for i in range(3): box('Jaw vent',head,(-.12+i*.12,-.345,.633),(.04,.08,.02),p['ink'],.007)
    box('Back reactor',root,(0,1.21,-.42),(.80,.68,.31),p['dark'],.065)
    for side in (-1,1):
        cylinder('Reactor port',root,(side*.22,1.28,-.60),.13,.14,p['ink'],axis='z')
        box('Hip stabilizer',root,(side*.43,.65,-.08),(.31,.28,.42),p['color'],.045)
    root['author_height']=2.875;root['chassis']='terra'
    return root

def build_momo():
    p=palette('momo');root=empty('Rig');torso=_core_body(root,p,'momo')
    head=empty('Head',root,(0,1.91,.025))
    ellipsoid('Pearl helmet',head,(0,.10,-.04),(1.44,1.12,1.02),p['pale'],32,16)
    ellipsoid('Petal face rim',head,(0,-.06,.39),(1.19,.89,.25),p['dark'],32,16)
    ellipsoid('Pearl face',head,(0,-.065,.472),(1.09,.81,.14),p['pale'],32,16)
    plate('Petal forehead',head,[(-.58,.21),(-.43,.52),(-.10,.66),(0,.55),(.12,.66),(.43,.50),(.59,.20),(.28,.08),(0,.14),(-.28,.08)],.49,.22,p['color'],.075)
    diamond('Forehead pearl',head,(0,.37,.595),.18,.25,.045,p['white'])
    diamond('Forehead light',head,(0,.38,.63),.08,.12,.025,p['accent'])
    for side in (-1,1):
        ellipsoid('Eye dark setting',head,(side*.265,-.08,.551),(.36,.45,.060),p['dark'],24,12)
        ellipsoid('EyeLeft' if side<0 else 'EyeRight',head,(side*.265,-.065,.585),(.275,.355,.037),p['color'],24,12)
        ellipsoid('Eye pupil',head,(side*.265,-.09,.609),(.10,.20,.02),p['dark'],16,8)
        ellipsoid('Eye glint',head,(side*.265-.044,.018,.623),(.092,.117,.023),p['eye_glint'],16,8)
        ellipsoid('Eye lower glint',head,(side*.265+.039,-.178,.623),(.048,.044,.022),p['accent'],12,6)
        ellipsoid('Cheek blush',head,(side*.43,-.27,.538),(.14,.065,.03),p['color'],16,8)
        petal=ellipsoid('Split petal antenna',head,(side*.30,.72,-.09),(.255,.65,.24),p['pale'],24,12)
        petal.rotation_euler[1]=side*.23
        petal=ellipsoid('Antenna inner glow',head,(side*.30,.73,.042),(.095,.43,.038),p['color'],20,10)
        petal.rotation_euler[1]=side*.23
        cylinder('Ear halo housing',head,(side*.69,.045,-.025),.265,.19,p['color'],axis='x',vertices=24,bevel=.025)
        cylinder('Ear pearl cap',head,(side*.806,.045,-.025),.185,.07,p['pale'],axis='x',vertices=24)
        cylinder('Ear cyan core',head,(side*.85,.045,-.025),.095,.02,p['accent'],axis='x',vertices=20)
        plate('Petal jaw armor',head,mirror_profile([(.40,-.32),(.63,-.22),(.57,-.43),(.30,-.49)],side),.42,.18,p['color'],.04)
    line('Smile left',head,(-.078,-.32,.565),(0,-.355,.575),.019,p['dark'])
    line('Smile right',head,(0,-.355,.575),(.078,-.32,.565),.019,p['dark'])
    for child in root.children:
        if child.name=='LeftArm':
            ellipsoid('Soft wrist cover',child,(0,-.47,.13),(.36,.41,.35),p['pale'])
            diamond('Wrist petal',child,(0,-.48,.34),.14,.20,.035,p['color'])
        elif child.name in ('LeftLeg','RightLeg'):
            ellipsoid('Petal toe armor',child,(0,-.60,.24),(.46,.29,.58),p['pale'])
            ellipsoid('Toe highlight',child,(0,-.56,.48),(.17,.085,.035),p['color'],16,8)
    torus('Hover halo pack',root,(0,1.17,-.45),.30,.06,p['color'],axis='z')
    for side in (-1,1):
        ellipsoid('Hover petal',root,(side*.27,.94,-.46),(.24,.45,.20),p['pale'])
        cylinder('Hover thruster',root,(side*.27,.71,-.46),.10,.06,p['accent'],axis='y')
    root['author_height']=2.955;root['chassis']='momo'
    return root

def build_shadow():
    p=palette('shadow');root=empty('Rig');_core_body(root,p,'shadow')
    head=empty('Head',root,(0,1.91,.025))
    ellipsoid('Obsidian helmet',head,(0,.10,-.055),(1.26,1.02,.95),p['dark'])
    plate('Faceted hood',head,[(-.62,.10),(-.47,.48),(-.16,.66),(0,.49),(.22,.62),(.53,.39),(.61,.06),(.35,-.15),(0,-.34),(-.37,-.12)],.46,.28,p['color'],.03)
    plate('Shadow visor',head,[(-.48,.02),(-.16,.10),(0,-.02),(.19,.10),(.48,.01),(.39,-.30),(0,-.42),(-.41,-.29)],.525,.075,p['ink'],.02)
    for side in (-1,1):
        plate('EyeLeft' if side<0 else 'EyeRight',head,mirror_profile([(.09,-.11),(.42,.005),(.36,-.21),(.18,-.25)],side),.578,.029,p['energy'],.012)
        plate('Eye glint',head,mirror_profile([(.13,-.12),(.34,-.045),(.27,-.15)],side),.611,.014,p['accent'],.005)
        plate('Tall stealth vane',head,mirror_profile([(.37,.36),(.60,1.11),(.80,.70),(.63,.16)],side),-.05,.23,p['dark'],.024)
        plate('Vane violet edge',head,mirror_profile([(.50,.53),(.60,1.08),(.66,.72),(.57,.37)],side),.195,.033,p['pale'],.009)
        plate('Swept temple blade',head,mirror_profile([(.48,.18),(.94,.60),(.78,.09),(.53,-.10)],side),.20,.18,p['color'],.02)
        plate('Cheek guard',head,mirror_profile([(.38,-.24),(.61,-.06),(.54,-.36),(.13,-.49)],side),.48,.15,p['dark'],.017)
        cylinder('Phase sensor',head,(side*.67,.045,-.03),.14,.15,p['ink'],axis='x')
        cylinder('Phase sensor lens',head,(side*.765,.045,-.03),.075,.028,p['energy'],axis='x')
        plate('Permanent stabilizer',root,mirror_profile([(.18,1.3),(.73,1.06),(.90,.42),(.44,.68)],side),-.36,.10,p['dark'],.018)
        plate('Stabilizer glow',root,mirror_profile([(.48,.97),(.71,.68),(.73,.56),(.51,.74)],side),-.24,.025,p['energy'],.005)
    diamond('Phase crest',head,(0,.29,.545),.12,.31,.04,p['energy'])
    plate('Pointed chin',head,[(-.12,-.37),(0,-.50),(.12,-.37),(0,-.32)],.54,.09,p['pale'],.01)
    root['author_height']=3.02;root['chassis']='shadow'
    return root

def build_lumi():
    p=palette('lumi');root=empty('Rig');_core_body(root,p,'lumi')
    head=empty('Head',root,(0,1.92,.02))
    ellipsoid('Ivory helmet',head,(0,.13,-.05),(1.38,1.11,1.02),p['pale'],32,16)
    ellipsoid('Gold face setting',head,(0,-.09,.398),(1.20,.75,.28),p['color'])
    ellipsoid('Prismatic visor',head,(0,-.085,.501),(1.07,.64,.125),p['ink'])
    plate('Ivory crown',head,[(-.59,.13),(-.43,.53),(0,.70),(.43,.53),(.59,.13),(.40,.03),(0,.13),(-.40,.03)],.49,.24,p['pale'],.06)
    plate('Gold crown band',head,[(-.54,.18),(-.39,.33),(0,.23),(.39,.33),(.54,.18),(.39,.11),(0,.16),(-.39,.11)],.57,.055,p['color'],.015)
    diamond('Forehead prism cradle',head,(0,.44,.59),.26,.31,.06,p['color'])
    diamond('Forehead prism',head,(0,.46,.638),.12,.17,.035,p['energy'])
    for side in (-1,1):
        ellipsoid('EyeLeft' if side<0 else 'EyeRight',head,(side*.24,-.10,.574),(.28,.32,.04),p['energy'],24,12)
        ellipsoid('Eye glint',head,(side*.24-.04,-.025,.60),(.062,.074,.023),p['eye_glint'],16,8)
        plate('Gold antenna',head,mirror_profile([(.40,.37),(.56,1.06),(.74,.77),(.58,.32)],side),.04,.20,p['color'],.028)
        plate('Antenna ivory inlay',head,mirror_profile([(.49,.49),(.57,.91),(.65,.73),(.55,.45)],side),.253,.032,p['pale'],.012)
        cylinder('Round temple housing',head,(side*.68,.07,-.015),.28,.17,p['color'],axis='x',vertices=24)
        cylinder('Temple pearl',head,(side*.785,.07,-.015),.20,.06,p['pale'],axis='x',vertices=24)
        cylinder('Temple prism',head,(side*.826,.07,-.015),.095,.028,p['energy'],axis='x',vertices=16)
        plate('Ivory jaw',head,mirror_profile([(.42,-.23),(.59,-.10),(.55,-.35),(.22,-.44),(.12,-.34)],side),.51,.12,p['pale'],.025)
        plate('Gold jaw rim',head,mirror_profile([(.22,-.40),(.52,-.32),(.53,-.38),(.18,-.48)],side),.524,.035,p['color'],.01)
        plate('Prism backpack fin',root,mirror_profile([(.19,1.45),(.50,1.53),(.63,.98),(.29,.91)],side),-.38,.11,p['pale'],.025)
        diamond('Backpack power cell',root,(side*.39,1.22,-.27),.18,.36,.045,p['color'])
    root['author_height']=2.98;root['chassis']='lumi'
    return root

def build_kai():
    p=palette('kai');root=empty('Rig');_core_body(root,p,'kai')
    head=empty('Head',root,(0,1.90,.035))
    ellipsoid('Azure helmet backing',head,(0,.10,-.04),(1.30,1.02,.99),p['dark'])
    plate('Split blue crown',head,[(-.60,.13),(-.49,.48),(-.23,.66),(0,.32),(.24,.68),(.52,.47),(.62,.09),(.39,-.04),(0,-.25),(-.36,-.01)],.49,.27,p['color'],.028)
    plate('Midnight visor',head,[(-.49,.03),(0,-.12),(.49,.03),(.43,-.28),(0,-.43),(-.43,-.27)],.526,.105,p['ink'],.02)
    plate('Central targeting blade',head,[(-.09,.40),(0,.91),(.12,.54),(.07,.015),(0,-.13),(-.06,.03)],.57,.10,p['pale'],.018)
    diamond('Targeting sapphire',head,(0,.31,.68),.07,.21,.03,p['energy'])
    for side in (-1,1):
        plate('EyeLeft' if side<0 else 'EyeRight',head,mirror_profile([(.10,-.14),(.43,-.02),(.39,-.24),(.21,-.31)],side),.643,.028,p['energy'],.014)
        plate('Eye glint',head,mirror_profile([(.17,-.145),(.35,-.08),(.31,-.16)],side),.674,.014,p['eye_glint'],.003)
        plate('Tall blue sensor fin',head,mirror_profile([(.42,.30),(.67,1.10),(.85,.87),(.74,.36),(.54,.09)],side),.01,.27,p['color'],.025)
        plate('Sensor white tip',head,mirror_profile([(.60,.78),(.67,1.07),(.79,.86),(.68,.61)],side),.294,.04,p['pale'],.011)
        plate('Secondary swept fin',head,mirror_profile([(.53,.07),(.90,.38),(.74,-.01),(.59,-.15)],side),-.02,.23,p['dark'],.02)
        plate('Blue cheek armor',head,mirror_profile([(.43,-.19),(.62,-.10),(.59,-.38),(.20,-.48),(.25,-.32)],side),.49,.16,p['color'],.02)
        plate('White jaw accent',head,mirror_profile([(.25,-.38),(.47,-.31),(.49,-.39),(.20,-.49)],side),.63,.04,p['pale'],.012)
        cylinder('Optic hinge',head,(side*.68,.055,-.02),.18,.16,p['ink'],axis='x')
        cylinder('Optic blue ring',head,(side*.78,.055,-.02),.13,.03,p['color'],axis='x')
        cylinder('Optic cyan dot',head,(side*.802,.055,-.02),.06,.027,p['energy'],axis='x')
        cylinder('Flux booster',root,(side*.25,1.16,-.45),.13,.49,p['dark'],axis='y')
        cylinder('Booster emitter',root,(side*.25,.895,-.45),.10,.04,p['energy'],axis='y')
    root['author_height']=3.00;root['chassis']='kai'
    return root

def build_zero():
    p=palette('zero');root=empty('Rig');_core_body(root,p,'zero')
    head=empty('Head',root,(0,1.89,.02))
    ellipsoid('Graphite helmet',head,(0,.10,-.07),(1.34,1.03,.97),p['dark'])
    plate('Wildcard crown',head,[(-.62,.11),(-.53,.46),(-.15,.67),(0,.48),(.20,.61),(.52,.42),(.61,.08),(.32,-.02),(0,-.27),(-.35,.0)],.50,.27,p['color'],.035)
    plate('Black faceplate',head,[(-.50,.015),(-.27,-.04),(0,-.15),(.29,-.02),(.49,.03),(.41,-.30),(0,-.44),(-.41,-.29)],.54,.095,p['ink'],.02)
    for side in (-1,1):
        plate('EyeLeft' if side<0 else 'EyeRight',head,mirror_profile([(.09,-.155),(.43,-.055),(.37,-.235),(.20,-.29)],side),.646,.027,p['energy'],.012)
        plate('Eye highlight',head,mirror_profile([(.15,-.16),(.37,-.08),(.29,-.17)],side),.677,.01,p['accent'],.004)
        plate('Raked graphite horn',head,mirror_profile([(.43,.20),(.79,1.06),(.84,.58),(.62,.12)],side),-.05,.25,p['color'],.02)
        plate('Crimson horn slash',head,mirror_profile([(.58,.47),(.79,1.04),(.73,.62),(.61,.30)],side),.216,.034,p['energy'],.008)
        plate('Graphite jaw blade',head,mirror_profile([(.43,-.22),(.62,-.04),(.56,-.39),(.20,-.47)],side),.50,.17,p['dark'],.02)
        plate('Red jaw edge',head,mirror_profile([(.35,-.35),(.54,-.29),(.50,-.41),(.24,-.46)],side),.68,.034,p['energy'],.01)
        cylinder('Adaptive hinge',head,(side*.68,.04,-.045),.19,.16,p['ink'],axis='x')
        cylinder('Hinge armor',head,(side*.778,.04,-.045),.12,.035,p['pale'],axis='x',vertices=10)
        cylinder('Hinge red lens',head,(side*.802,.04,-.045),.052,.02,p['energy'],axis='x')
        plate('Permanent hip vane',root,mirror_profile([(.28,.76),(.61,.87),(.53,.39),(.33,.46)],side),-.10,.22,p['color'],.025)
        plate('Hip red inset',root,mirror_profile([(.42,.67),(.53,.76),(.47,.46)],side),.143,.025,p['energy'],.006)
    plate('Asymmetric crown inlay',head,[(-.28,.46),(-.15,.64),(.07,.24),(-.005,.05)],.79,.025,p['energy'],.009)
    plate('Chin guard',head,[(-.13,-.40),(0,-.48),(.13,-.40),(0,-.33)],.62,.08,p['pale'],.01)
    root['author_height']=2.95;root['chassis']='zero'
    return root

MODULE_DONORS = {'arc_blade':'nova','fin_plate':'nova','pile_cannon':'terra','bulwark':'terra','burst_knuckle':'kuren','vent_shell':'kuren','halo_caster':'momo','halo_shell':'momo','phase_talon':'shadow','mirage_mantle':'shadow','prism_emitter':'lumi','prism_shell':'lumi','rail_lance':'kai','flux_frame':'kai','switch_driver':'zero','adaptive_shell':'zero'}
SHELLS = ('fin_plate','vent_shell','bulwark','halo_shell','mirage_mantle','prism_shell','flux_frame','adaptive_shell')

def build_module(name):
    donor=MODULE_DONORS[name]
    p=palette(donor)
    root=empty('Module')
    root['module_id']=name
    if name in SHELLS:
        return _shell(root,p,name)
    cylinder('Universal coupler',root,(0,0,0),.155,.25,p['joint'],axis='x')
    cylinder('Coupler light',root,(.04,0,0),.168,.033,p['energy'],axis='x')
    if name=='arc_blade':
        box('Blade forearm',root,(.17,-.12,0),(.40,.43,.36),p['color'],.055)
        plate('Blade white shroud',root,[(-.015,.07),(.34,.05),(.44,-.22),(.17,-.41),(-.04,-.27)],.24,.15,p['white'])
        diamond('Blade battery',root,(.20,-.11,.267),.14,.23,.035,p['color'])
        diamond('Blade indicator',root,(.20,-.11,.291),.055,.12,.02,p['energy'])
        # Swept saber is a curved physical silhouette, not a rectangular glow stick.
        plate('Saber dark spine',root,[(.28,-.30),(.62,-.16),(.99,.18),(1.23,.57),(1.14,.14),(.81,-.26),(.46,-.43)],.11,.08,p['color'],.007)
        plate('Saber energy edge',root,[(.35,-.30),(.67,-.10),(1.22,.60),(1.08,.11),(.78,-.23),(.46,-.39)],.161,.025,p['energy'],.004)
        plate('Saber white hot core',root,[(.42,-.30),(.74,-.09),(1.18,.52),(1.06,.17),(.72,-.15)],.178,.008,p['eye_glint'],.001)
        bolt(root,(.035,-.24,.27),p,.021)
    elif name=='pile_cannon':
        box('Breech',root,(.27,0,0),(.74,.71,.69),p['color'],.065)
        box('Breech lower rim',root,(.24,-.29,.03),(.62,.13,.70),p['dark'],.025)
        cylinder('Main barrel',root,(.85,.025,0),.23,1.17,p['ink'],axis='x',vertices=16,bevel=.025)
        for x in (.45,.67,1.01,1.30):
            cylinder('Barrel clamp',root,(x,.025,0),.28,.12,p['color'] if x in (.45,1.30) else p['steel'],axis='x')
        cylinder('Muzzle crown',root,(1.43,.025,0),.34,.22,p['color'],axis='x',vertices=12,bevel=.03)
        cylinder('Muzzle black bore',root,(1.552,.025,0),.251,.024,p['ink'],axis='x',vertices=16)
        cylinder('Bore coil',root,(1.568,.025,0),.154,.02,p['energy'],axis='x',vertices=16)
        cylinder('Bore center',root,(1.58,.025,0),.09,.023,p['white'],axis='x',vertices=12)
        for side in (-1,1):
            line('External recoil piston',root,(.25,.25,side*.26),(1.06,.25,side*.26),.065,p['steel'])
            box('Piston jacket',root,(.44,.25,side*.26),(.33,.16,.16),p['dark'],.02)
        plate('Breech cheek',root,[(-.03,.24),(.45,.24),(.54,.04),(.40,-.26),(0,-.25)],.385,.1,p['pale'])
        for i in range(3): box('Heat vent',root,(.08+i*.13,.06,.447),(.045,.20,.022),p['ink'],.008,angle=-.3)
        box('Cannon sight',root,(.72,.355,0),(.25,.085,.15),p['energy'],.012)
        bolt(root,(.35,-.15,.45),p)
    elif name=='burst_knuckle':
        box('Gauntlet body',root,(.32,-.05,0),(.70,.64,.64),p['color'],.08)
        plate('Knuckle crest',root,[(0,.17),(.49,.21),(.66,.01),(.42,-.26),(.08,-.30)],.38,.13,p['color'],.04)
        for i in range(3):
            cylinder('Burst chamber',root,(.70,-.19+i*.17,0),.08,.18,p['dark'],axis='x',vertices=10)
            cylinder('Chamber ignition',root,(.80,-.19+i*.17,0),.052,.026,p['energy'],axis='x',vertices=10)
            box('Knuckle vent',root,(.13+i*.13,.09,.458),(.06,.15,.018),p['ink'],.01,angle=-.35)
        plate('Flare wedge',root,[(.05,.21),(.18,.45),(.50,.28)],.11,.34,p['pale'])
        bolt(root,(.40,-.20,.44),p,.028)
    elif name=='halo_caster':
        ellipsoid('Petal housing',root,(.20,-.12,0),(.62,.61,.57),p['color'])
        plate('Pearl cheek',root,[(-.02,.08),(.31,.16),(.49,-.05),(.30,-.33),(.07,-.28)],.32,.12,p['white'],.055)
        diamond('Caster lens',root,(.25,-.06,.455),.24,.29,.05,p['energy'])
        torus('Emitter halo',root,(.47,.20,0),.28,.045,p['accent'],axis='x')
        for i in range(3):
            angle=i*math.tau/3
            ellipsoid('Floating petal',root,(.47,.20+math.sin(angle)*.32,math.cos(angle)*.32),(.14,.17,.17),p['pale'])
    elif name=='phase_talon':
        box('Phase gauntlet',root,(.24,-.10,0),(.56,.48,.45),p['dark'],.055)
        plate('Violet forearm plate',root,[(0,.15),(.39,.12),(.52,-.23),(.27,-.38),(.02,-.27)],.30,.13,p['color'])
        diamond('Phase capacitor',root,(.25,-.08,.454),.18,.24,.04,p['energy'])
        for index in range(3):
            z=.20-index*.19
            plate('Talon spine',root,[(.32,.05),(.65,.30),(1.17,.19),(.85,-.04),(.47,-.24)],z,.075,p['pale'],.012)
            plate('Talon energy edge',root,[(.59,.18),(1.14,.19),(.80,-.06),(.53,-.18)],z+.04,.022,p['energy'],.004)
    elif name=='prism_emitter':
        ellipsoid('Ivory emitter housing',root,(.23,-.09,0),(.61,.56,.55),p['pale'])
        cylinder('Prism bearing',root,(.50,.01,0),.24,.27,p['color'],axis='x',vertices=12)
        torus('Prism containment halo',root,(.72,.01,0),.29,.046,p['color'],axis='x')
        for side in (-1,1):
            line('Prism cage',root,(.41,side*.21,-.12),(.92,side*.15,0),.032,p['pale'])
        diamond('Floating prism',root,(.84,.01,.10),.27,.47,.22,p['energy'])
        diamond('Emitter gold badge',root,(.18,-.09,.34),.19,.26,.035,p['color'])
    elif name=='rail_lance':
        box('Rail receiver',root,(.30,-.02,0),(.76,.57,.50),p['color'],.055)
        plate('Rail receiver ivory shroud',root,[(-.03,.18),(.54,.19),(.64,.0),(.43,-.25),(.06,-.26)],.31,.105,p['pale'])
        box('Rail channel',root,(1.06,.045,0),(1.56,.18,.19),p['ink'],.02)
        for side in (-1,1):
            box('Parallel accelerator rail',root,(1.13,.045,side*.15),(1.45,.18,.10),p['dark'],.018)
            box('Cyan rail winding',root,(1.11,.152,side*.15),(1.28,.035,.055),p['energy'],.005)
            for index in range(4): box('Rail clamp',root,(.65+index*.32,.045,side*.15),(.09,.25,.15),p['color'],.015)
        box('Split muzzle crown',root,(1.85,.045,0),(.15,.33,.46),p['pale'],.025)
        box('Muzzle bore',root,(1.94,.045,0),(.03,.14,.20),p['ink'],.006)
        box('Rail focusing light',root,(1.96,.045,0),(.016,.075,.08),p['energy'],.002)
        cylinder('Charge capacitor',root,(.27,-.02,.43),.115,.07,p['energy'],axis='z',vertices=12)
        for index in range(3): box('Receiver vent',root,(.13+index*.12,.17,.436),(.045,.09,.025),p['dark'],.008)
    elif name=='switch_driver':
        box('Adaptive forearm',root,(.25,-.03,0),(.61,.55,.52),p['color'],.055)
        cylinder('Tri-mode drum',root,(.63,-.025,0),.30,.34,p['dark'],axis='x',vertices=12)
        cylinder('Drum endplate',root,(.82,-.025,0),.25,.06,p['pale'],axis='x',vertices=6)
        for index in range(3):
            angle=index*math.tau/3
            cylinder('Mode emitter',root,(.861,-.025+math.sin(angle)*.17,math.cos(angle)*.17),.067,.03,p['energy'],axis='x',vertices=8)
        plate('Driver dorsal blade',root,[(.06,.21),(.45,.43),(.95,.20),(.53,.23),(.24,.12)],.04,.20,p['color'],.02)
        plate('Driver red cutting edge',root,[(.30,.34),(.46,.41),(.93,.20),(.59,.27)],.253,.03,p['energy'],.006)
        diamond('Mode indicator',root,(.26,-.03,.34),.16,.21,.04,p['energy'])
    return root

def _shell(root,p,name):
    plate('Chest underplate',root,[(-.40,.23),(.40,.23),(.38,-.20),(0,-.35),(-.38,-.20)],.405,.12,p['dark'],.035)
    plate('Chest outer armor',root,[(-.42,.21),(-.18,.14),(0,.24),(.18,.14),(.42,.21),(.37,-.15),(0,-.30),(-.37,-.15)],.49,.12,p['white'] if name=='fin_plate' else p['color'],.04)
    diamond('Chest crest',root,(0,.015,.565),.25,.30,.075,p['color'] if name=='fin_plate' else p['pale'])
    diamond('Crest indicator',root,(0,.065,.61),.082,.12,.02,p['energy'])
    for side in (-1,1):
        box('Shoulder support',root,(side*.55,.22,-.04),(.40,.27,.45),p['dark'],.055)
        plate('Shoulder armor',root,mirror_profile([(.37,.36),(.66,.43),(.86,.22),(.77,.04),(.47,.05)],side),.22,.45,p['white'] if name=='fin_plate' else p['color'],.045)
        if name=='fin_plate':
            plate('Shoulder cobalt inset',root,mirror_profile([(.51,.34),(.68,.38),(.78,.23),(.62,.26)],side),.273,.04,p['color'],.012)
        elif name=='bulwark':
            box('Fortress pauldrons',root,(side*.66,.25,-.02),(.69,.55,.66),p['color'],.05)
            for i in range(3): box('Fortress stripe',root,(side*.65,.16+i*.1,.33),(.32,.04,.03),p['pale'],.012)
        elif name=='vent_shell':
            plate('Heat wing',root,mirror_profile([(.44,.25),(.94,.41),(.71,-.04),(.46,.01)],side),-.05,.32,p['color'],.03)
            for i in range(2): box('Vent exhaust',root,(side*(.57+i*.13),.18,.25),(.055,.18,.04),p['ink'],.01)
        elif name=='halo_shell':
            ellipsoid('Petal pauldrons',root,(side*.60,.24,-.05),(.54,.46,.56),p['pale'])
            diamond('Petal light',root,(side*.60,.22,.25),.14,.20,.04,p['accent'])
        elif name=='mirage_mantle':
            plate('Mirage layered pauldron',root,mirror_profile([(.37,.33),(.90,.51),(.72,.04),(.46,-.01)],side),.16,.30,p['dark'],.025)
            plate('Mirage lavender inset',root,mirror_profile([(.53,.28),(.79,.39),(.67,.14)],side),.475,.03,p['energy'],.008)
        elif name=='prism_shell':
            ellipsoid('Ivory shoulder canopy',root,(side*.61,.25,-.02),(.55,.42,.58),p['pale'])
            plate('Gold shoulder rim',root,mirror_profile([(.40,.31),(.62,.39),(.86,.22),(.79,.09),(.57,.14)],side),.28,.075,p['color'],.02)
            diamond('Shoulder prism',root,(side*.62,.24,.38),.15,.22,.05,p['energy'])
        elif name=='flux_frame':
            plate('Flux shoulder fin',root,mirror_profile([(.40,.34),(.75,.53),(.94,.22),(.78,.08),(.45,.11)],side),.16,.27,p['color'],.025)
            plate('Flux white stripe',root,mirror_profile([(.54,.35),(.75,.47),(.85,.31),(.63,.27)],side),.445,.025,p['pale'],.01)
            cylinder('Flux coil',root,(side*.69,.13,-.22),.12,.21,p['energy'],axis='y')
        elif name=='adaptive_shell':
            plate('Adaptive shoulder plate',root,mirror_profile([(.37,.31),(.68,.43),(.91,.21),(.73,.05),(.46,.08)],side),.24,.29,p['dark'],.03)
            plate('Crimson adaptive stripe',root,mirror_profile([(.49,.27),(.68,.35),(.80,.23),(.61,.19)],side),.55,.025,p['energy'],.008)
        bolt(root,(side*.30,-.09,.51),p,.021)
    return root

def consolidate(root):
    """Join static meshes per pivot, leaving eyes/Core separate for animation/feedback."""
    pivots=[obj for obj in [root]+list(root.children_recursive) if obj.type=='EMPTY']
    for pivot in pivots:
        meshes=[obj for obj in pivot.children if obj.type=='MESH' and obj.name not in ('Core','EyeLeft','EyeRight')]
        if len(meshes)<2: continue
        bpy.ops.object.select_all(action='DESELECT')
        for obj in meshes: obj.select_set(True)
        bpy.context.view_layer.objects.active=meshes[0]
        bpy.ops.object.join()
        bpy.context.object.name=pivot.name+'Armor'

def export(root,path,blend_path):
    consolidate(root)
    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    for obj in root.children_recursive: obj.select_set(True)
    bpy.context.view_layer.objects.active=root
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,
        export_apply=True,export_materials='EXPORT',export_cameras=False,export_lights=False,export_extras=True)
    vertices=sum(len(obj.data.vertices) for obj in root.children_recursive if obj.type=='MESH')
    print(f'MECHPOP ASSET {path.name}: {vertices} vertices, {len(root.children_recursive)} nodes')

def clear():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)

if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    parser=argparse.ArgumentParser();parser.add_argument('--only',default='nova');parser.add_argument('--modules',action='store_true');parser.add_argument('--module-only',default='')
    options=parser.parse_args(args)
    clear()
    builders={'nova':build_nova,'kuren':build_kuren,'terra':build_terra,'momo':build_momo,'shadow':build_shadow,'lumi':build_lumi,'kai':build_kai,'zero':build_zero}
    for chassis in filter(None,options.only.split(',')):
        clear();root=builders[chassis]();export(root,EXPORT/f'{chassis}.glb',ART/f'{chassis}.blend')
    if options.modules or options.module_only:
        for name in (MODULE_DONORS if options.modules else options.module_only.split(',')):
            clear();root=build_module(name);export(root,MODULES/f'{name}.glb',ART/f'{name}.blend')
