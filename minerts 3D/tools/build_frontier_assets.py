"""Rebuild editable Blender sources and Godot GLBs: blender -b -t 2 -P tools/build_frontier_assets.py."""
import bpy, math, random, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/frontier'; SRC=ROOT/'art/blender'
OUT.mkdir(exist_ok=True,parents=True); SRC.mkdir(exist_ok=True,parents=True)
random.seed(1337)
bpy.context.preferences.filepaths.save_version=0
M={}; parts={}; manifest={}
def mat(name,hexcol,metal=0,emission=0):
    if name in M:return M[name]
    c=tuple(int(hexcol[i:i+2],16)/255 for i in (0,2,4))
    c=tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in c)
    m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*c,1);bs.inputs['Metallic'].default_value=metal;bs.inputs['Roughness'].default_value=.72 if not metal else .38
    if emission:bs.inputs['Emission Color'].default_value=(*c,1);bs.inputs['Emission Strength'].default_value=emission
    M[name]=m;return m
colors={'wood':'684737','plank':'a07a52','endgrain':'c5a779','stone':'77858a','dark':'25353c','steel':'a8bec4','gold':'d6ae64','cloth':'32677a','leather':'61493a','skin':'dfac83','hair':'513a2e','leaf':'537c48','leaflight':'85a75e','pine':'315e50','pine2':'487863','birch':'e0d9b9','roof':'597c7e','roof2':'759592','bone':'d8d3b7','moss':'658451','zombie':'809264','red':'d8694d','eyes':'f9a45a','grass':'78945a','flower':'dfb7b7','ember':'ffc777','creeper':'76aa57'}
for n,c in colors.items():mat(n,c,.7 if n in ('steel','gold') else 0,2 if n in ('eyes','ember') else 0)
def clear():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    for a in list(bpy.data.actions):bpy.data.actions.remove(a)
    parts.clear()
def finish(o,name,material,bone=None,bevel=0):
    o.name=name;o.data.materials.append(M[material])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Hand-cut edges','BEVEL');mod.width=bevel;mod.segments=1
        bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
    if bone:parts.setdefault(bone,[]).append(o)
    return o
def box(name,pos,size,material,bone=None,bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.scale=size
    return finish(o,name,material,bone,bevel)
def ico(name,pos,size,material,bone=None,sub=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1,location=pos);o=bpy.context.object;o.scale=size
    return finish(o,name,material,bone)
def cone(name,pos,r1,r2,depth,material,bone=None,vertices=8):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=r1,radius2=r2,depth=depth,location=pos)
    return finish(bpy.context.object,name,material,bone)
def beam(name,a,b,r,material,bone=None):
    a,b=Vector(a),Vector(b);o=cone(name,(a+b)/2,r,r*.85,(b-a).length,material,bone)
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o
def join_objects(objects,name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();o=bpy.context.object;o.name=name;return o

def rig_character(name,spider=False,creeper=False):
    bpy.ops.object.armature_add();rig=bpy.context.object;rig.name=name+'_Rig';bpy.ops.object.mode_set(mode='EDIT')
    bones=rig.data.edit_bones;bones.remove(bones[0])
    pivots={'Body':(0,0,.72),'Head':(0,0,1.28),'Arm_L':(-.34,0,1.13),'Arm_R':(.34,0,1.13),'Leg_L':(-.16,0,.65),'Leg_R':(.16,0,.65)}
    if spider:pivots={'Body':(0,0,.48),'Head':(0,-.42,.5),**{'Leg_'+str(i):(side*.26, .27-(i//2)*.18,.46) for i,side in enumerate([-1,1]*4)}}
    if creeper:pivots={'Body':(0,0,.58),'Head':(0,0,1.13),**{'Leg_'+str(i):((-.23 if i%2==0 else .23),(-.21 if i<2 else .21),.35) for i in range(4)}}
    for n,p in pivots.items():
        b=bones.new(n);b.head=p;b.tail=Vector(p)+Vector((0,0,.18))
        if n!='Body':b.parent=bones['Body']
    bpy.ops.object.mode_set(mode='OBJECT')
    # One skinned body mesh; equipment remains separately controllable.
    merged=[]
    for bone,objs in parts.items():
        for obj in objs:
            vg=obj.vertex_groups.new(name=bone);vg.add(list(range(len(obj.data.vertices))),1,'REPLACE')
        ordinary=[o for o in objs if not o.name.startswith(('Axe_CTRL','Hammer_CTRL'))]
        if ordinary:merged.extend(ordinary)
    if merged:join_objects(merged,'Character')
    for o in list(bpy.context.scene.objects):
        if o.type=='MESH':
            mod=o.modifiers.new('Skeleton','ARMATURE');mod.object=rig;o.parent=rig
    rig.animation_data_create()
    for clip in ['Idle','Walk','Run','Attack','Gather','Build']:
        action=bpy.data.actions.new(clip);rig.animation_data.action=action
        for frame in (1,7,13,19,25):
            phase=(frame-1)/24*math.tau
            for pb in rig.pose.bones:
                pb.rotation_mode='XYZ';pb.rotation_euler=(0,0,0);pb.location=(0,0,0)
                n=pb.name
                if clip in ('Walk','Run'):
                    if n.startswith(('Leg','Arm')):
                        sign=1 if n.endswith(('L','0','2','4','6')) else -1
                        pb.rotation_euler.x=math.sin(phase)*(.5 if clip=='Walk' else .75)*sign
                        if spider:pb.rotation_euler.z=math.sin(phase)*.24*sign
                    if n=='Body':pb.location.y=abs(math.sin(phase))*.025
                elif clip in ('Attack','Gather','Build'):
                    if n=='Arm_R':pb.rotation_euler.x=-.4-math.sin(phase)*.95
                    if n=='Arm_L':pb.rotation_euler.x=-.45
                    if n=='Head':pb.rotation_euler.x=math.sin(phase)*.10
                    if n=='Body':pb.rotation_euler.x=math.sin(phase)*(.2 if spider else .08)
                elif n=='Body':pb.location.y=math.sin(phase)*.015
                if clip=='Attack' and name in ('archer','skeleton'):
                    if n=='Arm_L':pb.rotation_euler.x=-1.20
                    if n=='Arm_R':
                        pb.rotation_euler.x=-1.1
                        pb.rotation_euler.z=-.55+math.sin(phase)*.35
                pb.keyframe_insert(data_path='rotation_euler',frame=frame,group=n);pb.keyframe_insert(data_path='location',frame=frame,group=n)
        action.use_fake_user=True
    rig.animation_data.action=bpy.data.actions['Idle'];bpy.context.scene.frame_set(1)
    return rig

def bow(bone,x=-.45):
    points=[(x,-.2,.58),(x,-.34,.78),(x,-.42,1.02),(x,-.34,1.25),(x,-.2,1.45)]
    for i in range(4):beam('Curved yew bow',points[i],points[i+1],.035,'wood',bone)
    beam('Bowstring',points[0],points[-1],.008,'birch',bone)

def humanoid(kind):
    clear();knight=kind=='knight';skel=kind=='skeleton';zombie=kind=='zombie';worker=kind=='worker';arch=kind in ('archer','skeleton')
    bodymat='bone' if skel else ('steel' if knight else ('zombie' if zombie else 'cloth'))
    skin='bone' if skel else ('zombie' if zombie else 'skin')
    if skel:
        beam('Spine',(0,0,.74),(0,0,1.23),.065,'bone','Body')
        beam('Clavicle',(-.24,0,1.20),(.24,0,1.20),.045,'bone','Body')
    else:
        box('Torso',(0,0,.99),(.5,.29,.55),bodymat,'Body',.065)
    box('Belt',(0,0,.78),(.53,.33,.09),'leather','Body',.01)
    box('Buckle',(0,-.177,.79),(.10,.035,.08),'gold','Body',.01)
    box('Head',(0,-.01,1.49),(.42,.37,.43),skin,'Head',.055)
    for side in (-1,1):
        b='Arm_L' if side==-1 else 'Arm_R';l='Leg_L' if side==-1 else 'Leg_R'
        box('Sleeve',(side*.36,0,1.04),((.10,.12,.28) if skel else (.19,.24,.28)),bodymat,b)
        box('Forearm',(side*.37,-.025,.82),((.09,.10,.25) if skel else (.16,.19,.25)),skin,b)
        box('Hand',(side*.37,-.03,.66),(.18,.2,.15),skin,b)
        box('Leg',(side*.155,0,.43),((.10,.11,.44) if skel else (.18,.22,.44)),'bone' if skel else 'leather',l)
        box('Boot',(side*.155,-.06,.14),((.15,.29,.12) if skel else (.23,.34,.23)),'bone' if skel else 'dark',l)
        box('Eye',(side*.10,-.203,1.54),(.066,.025,.063),'eyes' if (zombie or skel) else 'dark','Head',.002)
    if skel:
        for h in range(4):box('Rib',(0,-.17,.89+h*.08),(.43,.055,.035),'birch','Body',.009)
        box('Nasal cavity',(0,-.207,1.43),(.05,.026,.07),'dark','Head',.002)
        for i in range(5):box('Tooth',(-.12+i*.06,-.214,1.34),(.035,.022,.056),'birch','Head',.002)
    elif knight:
        box('Helmet',(0,0,1.66),(.48,.42,.23),'steel','Head',.05)
        box('Visor',(0,-.215,1.55),(.44,.05,.13),'dark','Head',.009)
        for x in (-.14,-.07,0,.07,.14):box('Visor bars',(x,-.25,1.55),(.019,.03,.13),'steel','Head',.004)
        box('Nasal guard',(0,-.26,1.52),(.065,.04,.26),'gold','Head',.01)
        ico('Plume',(0,.015,1.88),(.085,.28,.15),'cloth','Head')
        for side in (-1,1):ico('Pauldron',(side*.35,0,1.18),(.24,.24,.15),'steel','Arm_L' if side<0 else 'Arm_R')
        box('Tabard',(0,-.178,.88),(.29,.04,.44),'cloth','Body')
        box('Shield',(-.48,-.15,.84),(.12,.40,.62),'steel','Arm_L',.08)
        box('Shield blue inlay',(-.55,-.15,.85),(.04,.29,.45),'cloth','Arm_L',.04)
        box('Shield heraldry',(-.578,-.15,.85),(.03,.09,.28),'gold','Arm_L',.008)
        box('Sword grip',(.39,-.11,.57),(.07,.08,.21),'leather','Arm_R',.008)
        box('Sword guard',(.39,-.11,.68),(.28,.10,.05),'gold','Arm_R',.008)
        box('Sword blade',(.39,-.11,1.02),(.095,.055,.64),'steel','Arm_R',.015)
        cone('Sword point',(.39,-.11,1.38),.065,0,.15,'steel','Arm_R',4)
    else:
        box('Hair',(0,.02,1.7),(.44,.35,.13),'hair','Head',.05)
        if worker:
            cone('Broad hat brim',(0,0,1.76),.35,.35,.06,'endgrain','Head',12)
            cone('Hat crown',(0,.02,1.85),.23,.16,.16,'endgrain','Head',8)
            box('Apron',(0,-.178,.89),(.35,.045,.45),'leather','Body',.02)
            box('Tool pouch',(.27,.02,.78),(.16,.25,.20),'endgrain','Body')
            a=box('Axe_CTRL_handle',(.38,-.12,.87),(.055,.06,.61),'wood','Arm_R',.004)
            b=box('Axe_CTRL_blade',(.49,-.12,1.10),(.3,.1,.2),'steel','Arm_R',.025)
            parts['Arm_R']=[o for o in parts['Arm_R'] if o not in (a,b)]
            parts['Arm_R'].append(join_objects([a,b],'Axe_CTRL'))
        if arch or kind=='scout':
            ico('Hood',(0,.045,1.67),(.29,.28,.19),'moss','Head',2)
            box('Quiver',(0,.23,1.05),(.20,.18,.47),'leather','Body')
            for x in (-.065,0,.065):beam('Arrow shaft',(x,.23,1.03),(x,.23,1.48),.012,'plank','Body')
    if arch:bow('Arm_L')
    if worker:
        box('Hammer_CTRL',(.38,-.12,.96),(.075,.075,.50),'wood','Arm_R',.006)
        # Tool head is joined below to keep one visibility control.
        h=box('HammerHead',(.38,-.12,1.17),(.27,.19,.17),'steel')
        shaft=bpy.data.objects['Hammer_CTRL'];join_objects([shaft,h],'Hammer_CTRL')
    rig_character(kind)
    export(kind,animated=True)

def creature(kind):
    clear()
    if kind=='creeper':
        box('Moss body',(0,0,.85),(.44,.37,.64),'creeper','Body',.03)
        box('Heavy square head',(0,-.01,1.40),(.58,.52,.53),'creeper','Head',.025)
        for i in range(4):box('Foot',((-.23 if i%2==0 else .23),(-.21 if i<2 else .21),.19),(.22,.34,.36),'moss','Leg_'+str(i),.025)
        for x in (-.14,.14):box('Empty eye',(x,-.279,1.46),(.13,.025,.13),'dark','Head',.002)
        box('Mouth',(0,-.281,1.29),(.19,.027,.17),'dark','Head',.002)
        for x in (-.095,.095):box('Mouth corners',(x,-.281,1.22),(.08,.028,.12),'dark','Head',.002)
        for i in range(12):box('Moss patch',(random.uniform(-.21,.21),-.205,random.uniform(.59,1.1)),(.10,.03,.10),'leaf','Body',.002)
        rig_character(kind,creeper=True)
    else:
        ico('Abdomen',(0,.34,.57),(.46,.58,.37),'dark','Body',2)
        ico('Thorax',(0,-.18,.49),(.31,.34,.25),'leather','Body',2)
        ico('Head',(0,-.47,.47),(.29,.23,.20),'dark','Head',2)
        for i in range(4):
            for side in (-1,1):
                idx=i*2+(1 if side==1 else 0);bone='Leg_'+str(idx)
                a=(side*.26,.27-i*.18,.46);b=(side*(.69+(.12 if i in (1,2) else 0)),.48-i*.34,.69);c=(side*(.95+(.12 if i in (1,2) else 0)),.66-i*.46,.055)
                beam('Upper leg',a,b,.065,'leather',bone);beam('Lower leg',b,c,.048,'dark',bone);ico('Joint',b,(.085,.085,.085),'moss',bone)
        for x in (-.18,-.065,.065,.18):ico('Amber eyes',(x,-.65,.52),(.043,.035,.04),'eyes','Head')
        for x in (-.12,.12):beam('Fang',(x,-.61,.43),(x,-.73,.31),.035,'bone','Head')
        rig_character(kind,spider=True)
    export(kind,animated=True)

def export(name,animated=False):
    bpy.context.scene.render.fps=24;bpy.context.scene.frame_start=1;bpy.context.scene.frame_end=25
    if not animated:
        meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.name not in ('GateDoor','DeepOreBlock','CropPlants')]
        if meshes:join_objects(meshes,'Geometry')
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.wm.save_as_mainfile(filepath=str(SRC/(name+'.blend')))
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_animations=animated,export_animation_mode='ACTIONS',export_force_sampling=True,export_materials='EXPORT')
    manifest[name]={'vertices':sum(len(o.data.vertices) for o in bpy.context.scene.objects if o.type=='MESH'),'animated':animated}

def roof(w,d,z):
    # True gabled roof, layered tile strips on both slopes.
    for side in (-1,1):
        for row in range(5):
            x=side*(row+.5)*w/10;h=z+(w*.30)*(1-(row+.5)/5)
            o=box('Roof shingles',(x,0,h),(w/5+.045,d+.25,.12),'roof' if row%2 else 'roof2',bevel=.008);o.rotation_euler.y=side*.54
    beam('Ridge cap',(0,-d/2-.15,z+w*.30),(0,d/2+.15,z+w*.30),.065,'gold')
def crate(pos,s=.5):
    x,y,z=pos;box('Crate',pos,(s,s,s),'plank')
    for dz in (-s*.33,s*.33):box('Crate band',(x,y-s/2-.015,z+dz),(s+.03,.045,.055),'wood',bevel=.003)
def building(kind):
    clear();w=2.8 if kind in ('workshop','barracks') else 1.8;d=w
    if kind=='campfire':
        for i in range(12):
            a=i*math.tau/12;ico('Hearth stone',(math.cos(a)*.69,math.sin(a)*.69,.17),(.22,.17,.16),'stone')
        for i in range(3):
            a=i*math.pi/3;beam('Charred log',(-math.cos(a)*.5,-math.sin(a)*.5,.22),(math.cos(a)*.5,math.sin(a)*.5,.32),.13,'wood')
        for i in range(5):cone('Flame',(random.uniform(-.2,.2),random.uniform(-.2,.2),.6),.17,0,.6+random.random()*.2,'ember',vertices=5)
    elif kind in ('hut','workshop','barracks'):
        tall=1.85 if kind=='barracks' else 1.35
        box('Stone footing',(0,0,.16),(w,d,.32),'stone')
        box('Plaster infill',(0,0,tall/2+.22),(w-.10,d-.10,tall),'endgrain')
        for x in (-w/2+.05,0,w/2-.05):
            for y in (-d/2,d/2):box('Timber framing',(x,y,tall/2+.22),(.10,.12,tall+.1),'wood',bevel=.008)
        for h in (.36,tall+.20):box('Crossbeam',(0,-d/2-.03,h),(w+.1,.12,.10),'wood',bevel=.008)
        box('Entrance',(0,-d/2-.055,.70),(.55,.08,.95),'wood')
        box('Door latch',(.17,-d/2-.11,.72),(.07,.025,.07),'gold',bevel=.005)
        for x in (-w*.31,w*.31):
            box('Window recess',(x,-d/2-.06,1.12),(.36,.08,.36),'dark')
            box('Window glow',(x,-d/2-.105,1.12),(.26,.018,.26),'ember')
            box('Window mullion',(x,-d/2-.125,1.12),(.035,.03,.31),'wood',bevel=.002)
        roof(w,d,tall+.28)
        if kind in ('workshop','barracks'):
            box('Chimney',(-w*.33,.5,tall*.75),(.43,.45,tall*1.9),'stone')
            for z in (.5,.85,1.2,1.55,1.9,2.25):box('Chimney course',(-w*.33,.5,z),(.46,.48,.05),'dark',bevel=.003)
            crate((w*.35,-d*.38,.4),.45)
        if kind=='barracks':
            for x in (-.85,.85):
                box('Blue banner',(x,-d/2-.14,1.5),(.26,.035,.65),'cloth')
                box('Gold sigil',(x,-d/2-.17,1.5),(.075,.02,.31),'gold',bevel=.003)
        if kind=='workshop':
            box('Anvil foot',(.6,-1,.55),(.38,.38,.6),'wood')
            box('Anvil',(.6,-1,.91),(.57,.26,.2),'steel')
    elif kind=='storage':
        box('Raised platform',(0,0,.12),(1.85,1.85,.24),'wood')
        for x in (-.78,.78):
            for y in (-.78,.78):box('Support',(x,y,.91),(.10,.10,1.6),'wood')
        roof(1.8,1.8,1.75)
        for p,s in [((-.4,-.3,.53),.57),((.35,.3,.53),.6),((-.4,.3,.5),.48)]:crate(p,s)
    elif kind=='wall':
        for x in (-.32,0,.32):cone('Pointed palisade',(x,0,.94),.18,.15,1.88,'wood',vertices=6);cone('Sharpened tip',(x,0,1.97),.17,0,.26,'endgrain',vertices=6)
        for z in (.45,1.3):box('Brace',(0,-.19,z),(.96,.12,.11),'plank',bevel=.005)
    elif kind=='gate':
        for x in (-.84,.84):box('Stone gatepost',(x,0,.98),(.28,.48,1.96),'stone')
        box('Lintel',(0,0,1.94),(1.94,.45,.24),'wood')
        door=box('GateDoor',(0,0,.86),(1.38,.16,1.50),'plank')
        # Separate mesh retained for hinge control.
    elif kind=='tower':
        box('Tower foundation',(0,0,.18),(1.9,1.9,.36),'stone')
        for x in (-.65,.65):
            for y in (-.65,.65):
                box('Tower post',(x,y,1.5),(.20,.20,2.8),'wood')
        for y in (-.67,.67):
            beam('Diagonal brace',(-.65,y,.4),(.65,y,2.5),.07,'plank')
            beam('Diagonal brace',(.65,y,.4),(-.65,y,2.5),.07,'plank')
        box('Watch platform',(0,0,2.65),(1.9,1.9,.20),'plank')
        for y in (-.88,.88):box('Parapet',(0,y,3.02),(1.9,.13,.52),'wood')
        for x in (-.88,.88):box('Parapet',(x,0,3.02),(.13,1.9,.52),'wood')
        for z in (.45,.72,.99,1.26,1.53,1.8,2.07,2.34):box('Ladder rung',(0,-.82,z),(.50,.07,.07),'endgrain',bevel=.004)
    elif kind=='mine':
        box('Pit collar',(0,0,.12),(1.85,1.85,.24),'stone')
        box('Dark shaft',(0,0,.25),(1.25,1.25,.03),'dark')
        for x in (-.68,.68):beam('Headframe',(x,0,.2),(x*.72,0,1.95),.12,'wood')
        beam('Winch beam',(-.85,0,1.92),(.85,0,1.92),.12,'wood')
        beam('Rope',(0,0,.25),(0,0,1.9),.018,'endgrain')
        for x in (-.5,.5):beam('Rail',(x,-.9,.3),(x,.9,.3),.025,'steel')
        crate((.55,-.5,.49),.45)
        ico('DeepOreBlock',(-.5,-.5,.45),(.2,.2,.25),'eyes',sub=1)
    export(kind)

def tree(kind):
    clear();pine=kind=='pine';birch=kind=='birch';autumn=kind=='autumn'
    trunk='birch' if birch else 'wood'
    beam('Tapered trunk',(0,0,0),(.10,.02,2.6 if pine else 2.3),.14,trunk)
    for i in range(5):
        a=i*math.tau/5;beam('Root',(0,0,.18),(math.cos(a)*.4,math.sin(a)*.4,.02),.055,trunk)
    if pine:
        for j in range(5):
            cone('Needle tier',(.07,0,1.25+j*.48),1.05-j*.16,.05,1.15,'pine' if j%2 else 'pine2',vertices=9)
            for k in range(3):
                a=k*math.tau/3+j;beam('Branch',(0,0,1+j*.35),(math.cos(a)*(.7-j*.1),math.sin(a)*(.7-j*.1),1.05+j*.35),.035,'wood')
    else:
        for i in range(7):
            a=i*2.4;r=.65 if i<6 else .0;h=2.2+(i%3)*.28
            p=(math.cos(a)*r,math.sin(a)*r,h)
            beam('Branch',(0,0,1.3),p,.055,trunk)
            ico('Faceted crown',p,(.76,.72,.70),'gold' if autumn and i%2 else ('red' if autumn else ('leaflight' if i%3 else 'leaf')),sub=2)
        if birch:
            for h in (.4,.8,1.2,1.6):box('Birch bark stripe',(.01,-.14,h),(.19,.018,.035),'dark',bevel=.001)
    export('tree_'+kind)

def prop(kind):
    clear()
    if kind=='rock':
        for i in range(3):ico('Weathered rock',(i*.23-.2,0,.18+i*.07),(.30,.28,.24+i*.06),'stone')
    elif kind=='fern':
        for i in range(7):
            a=i*math.tau/7
            for j in range(1,5):
                r=j*.09;ico('Fern leaf',(math.cos(a)*r,math.sin(a)*r,.30-r*.5),(.13,.055,.035),'leaflight')
    elif kind=='grass':
        for i in range(7):
            o=cone('Grass blade',(random.uniform(-.2,.2),random.uniform(-.2,.2),.14),.04,0,random.uniform(.18,.40),'grass',vertices=3);o.rotation_euler.y=random.uniform(-.35,.35)
    elif kind=='flowers':
        for i in range(5):
            x,y=random.uniform(-.25,.25),random.uniform(-.25,.25)
            beam('Stem',(x,y,0),(x,y,.3),.012,'grass');ico('Flower',(x,y,.31),(.085,.085,.035),'flower')
    elif kind=='stump':
        cone('Stump',(0,0,.2),.23,.19,.4,'wood');cone('Cut surface',(0,0,.405),.175,.175,.02,'endgrain')
    elif kind=='berries':
        ico('Bush',(0,0,.45),(.57,.5,.47),'leaf',sub=2)
        for i in range(9):
            a=i*2.4;ico('Berry',(math.cos(a)*.4,math.sin(a)*.4,.45+(i%3)*.1),(.055,.055,.055),'red')
    export('prop_'+kind)

for kind in ['worker','knight','archer','scout','zombie','skeleton']:humanoid(kind)
for kind in ['creeper','spider']:creature(kind)
for kind in ['campfire','hut','storage','wall','gate','tower','workshop','mine','barracks']:building(kind)
for kind in ['oak','pine','birch','autumn']:tree(kind)
for kind in ['rock','fern','grass','flowers','stump','berries']:prop(kind)
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
print('FRONTIER ASSETS COMPLETE',len(manifest))
