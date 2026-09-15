"""Detailed game assets, executed through MCP inside the user's live Blender."""
from pathlib import Path
source=Path(__file__).with_name('build_frontier_assets.py').read_text()
source=source[:source.index("for kind in ['worker'")].replace('bpy.context.preferences.filepaths.save_version=0','')
source=source.replace('use_selection=True,export_animations=', 'use_selection=True,use_active_scene=True,export_animations=')
exec(source)
mat('goblin','779452');mat('goblin_light','a3b66e');mat('tribal','6f405e');mat('tribal_light','a46577');mat('wolf','74777c');mat('wolf_dark','41484f');mat('wolf_cream','b7b4a3');mat('bear','604533');mat('bear_light','927158');mat('troll','718f82');mat('meat','984c4f');mat('sail','d8cdb4');mat('rope','a48b61')

def rig_custom(name,pivots,quadruped=False):
 bpy.ops.object.armature_add();rig=bpy.context.object;rig.name=name+'_Rig';bpy.ops.object.mode_set(mode='EDIT')
 bones=rig.data.edit_bones;bones.remove(bones[0])
 for n,p in pivots.items():
  bone=bones.new(n);bone.head=p;bone.tail=Vector(p)+Vector((0,0,.2))
  if n!='Body':bone.parent=bones['Body']
 bpy.ops.object.mode_set(mode='OBJECT')
 for bone,objects in parts.items():
  for o in objects:
   vg=o.vertex_groups.new(name=bone);vg.add(list(range(len(o.data.vertices))),1,'REPLACE')
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.name not in ('Axe_CTRL','Hammer_CTRL')]
 if meshes:join_objects(meshes,'Character')
 for o in list(bpy.context.scene.objects):
  if o.type=='MESH':
   mod=o.modifiers.new('Skeleton','ARMATURE');mod.object=rig;o.parent=rig
 rig.animation_data_create()
 for clip in ['Idle','Walk','Run','Attack','Gather','Build']:
  action=bpy.data.actions.new(clip);action.use_fake_user=True;rig.animation_data.action=action
  for frame in [1,5,9,13,17,21,25]:
   phase=(frame-1)/24*math.tau
   for pb in rig.pose.bones:
    pb.rotation_mode='XYZ';pb.rotation_euler=(0,0,0);pb.location=(0,0,0);n=pb.name
    sign=-1 if n.endswith(('L','0','3','4','7')) else 1
    if clip in ('Walk','Run'):
     if n.startswith(('Leg','Arm','Spider')):pb.rotation_euler.x=math.sin(phase)*(.48 if clip=='Walk' else .7)*sign
     if n.startswith('Spider'):pb.rotation_euler.z=math.cos(phase)*.2*sign
     if n=='Body':pb.location.y=abs(math.sin(phase))*.025
     if n=='Tail':pb.rotation_euler.y=math.sin(phase)*.16
    elif clip in ('Attack','Gather','Build'):
     if n=='Head' and quadruped:pb.rotation_euler.x=math.sin(phase)*.35
     if n=='Arm_R':pb.rotation_euler.x=-.5-math.sin(phase)*.9
     if n=='Arm_L':pb.rotation_euler.x=-.6
     if n=='Body':pb.rotation_euler.x=math.sin(phase)*.08
    elif n in ('Body','Head'):pb.rotation_euler.x=math.sin(phase)*.018
    pb.keyframe_insert(data_path='rotation_euler',frame=frame,group=n);pb.keyframe_insert(data_path='location',frame=frame,group=n)
 rig.animation_data.action=bpy.data.actions.get('Idle');bpy.context.scene.frame_set(1)
 return rig

def animal(kind):
 clear();bear=kind=='bear';s=1.45 if bear else 1.;body='bear' if bear else 'wolf';light='bear_light' if bear else 'wolf_cream';dark='leather' if bear else 'wolf_dark'
 def pos(p):return tuple(v*s for v in p)
 def ball(n,p,sz,m,b='Body',sub=2):return ico(n,pos(p),pos(sz),m,b,sub)
 ball('Ribcage',(0,.12,.78),(.34,.68,.42),body)
 ball('Shoulder hump',(0,-.3,.9),(.38,.36,.44),body)
 ball('Haunches',(0,.57,.7),(.30,.32,.36),body)
 ball('Chest fur',(0,-.44,.74),(.28,.30,.33),light)
 ball('Skull',(0,-.73,1.02),(.27,.29,.27),body,'Head')
 ball('Cheek L',(-.2,-.76,.94),(.14,.19,.18),light,'Head')
 ball('Cheek R',(.2,-.76,.94),(.14,.19,.18),light,'Head')
 ball('Muzzle',(0,-1.0,.93),(.16,.27 if not bear else .20,.13),light,'Head')
 ball('Lower jaw',(0,-1.02,.82),(.13,.22,.06),dark,'Head')
 ball('Wet nose',(0,-1.21,.96),(.12,.08,.085),'dark','Head')
 for side in [-1,1]:
  ball('Brow',(side*.15,-.92,1.115),(.14,.10,.055),dark,'Head')
  ball('Amber eye',(side*.21,-.943,1.075),(.039,.028,.033),'gold','Head')
  ball('Eye pupil',(side*.21,-.965,1.075),(.014,.015,.024),'dark','Head')
  if bear:ball('Round ear',(side*.235,-.63,1.25),(.13,.07,.14),body,'Head')
  else:
   o=cone('Pointed ear',pos((side*.19,-.62,1.37)),.13*s,0,.34*s,body,'Head',vertices=4);o.rotation_euler.y=side*.25
   cone('Inner ear',pos((side*.19,-.68,1.35)),.07*s,0,.21*s,light,'Head',vertices=3)
  for front in [-1,1]:
   bone='Leg_'+('F' if front<0 else 'B')+('L' if side<0 else 'R')
   y=-.4 if front<0 else .55
   ball('Upper leg',(side*.26,y,.55),(.15,.17,.28),body,bone)
   beam('Shin',pos((side*.27,y,.38)),pos((side*.29,y-.04,.13)),.075*s,body,bone)
   ball('Paw',(side*.29,y-.1,.075),(.12,.20,.075),dark,bone)
   for toe in [-1,0,1]:
    cone('Claw',pos((side*.29+toe*.048,y-.255,.06)),.022*s,0,.08*s,'bone',bone,vertices=5).rotation_euler.x=math.pi/2
  for j in range(5):
   cone('Ruff fur',pos((side*(.26+math.sin(j)*.02),-.36+j*.10,1.07)),.075*s,0,.23*s,body,'Body',vertices=4).rotation_euler.y=side*.7
 if not bear:
  beam('Bushy tail',pos((0,.67,.7)),pos((0,1.25,.42)),.15*s,body,'Tail');ball('Tail tip',(0,1.28,.39),(.10,.15,.11),dark,'Tail')
 pivots={'Body':pos((0,0,.7)),'Head':pos((0,-.55,.97)),'Tail':pos((0,.65,.7))}
 for side in [-1,1]:
  for front in [-1,1]:pivots['Leg_'+('F' if front<0 else 'B')+('L' if side<0 else 'R')]=pos((side*.26,-.4 if front<0 else .55,.68))
 rig_custom(kind,pivots,True);export(kind,True)

def goblin(kind):
 clear();troll=kind=='troll';rider=kind=='spider_rider';s=1.65 if troll else 1.;lift=.7 if rider else 0.;skin='troll' if troll else 'goblin';armor=kind in ('goblin_warrior','goblin_spearman','troll')
 def p(v):return (v[0]*s,v[1]*s,v[2]*s+lift)
 def b(n,v,sz,m,bone='Body',bevel=.025):return box(n,p(v),tuple(a*s for a in sz),m,bone,bevel)
 def ball(n,v,sz,m,bone='Body',sub=2):return ico(n,p(v),tuple(a*s for a in sz),m,bone,sub)
 ball('Barrel torso',(0,.03,.93),(.31,.23,.36),skin)
 b('Leather vest',(0,-.04,.95),(.48,.31,.42),'tribal')
 b('Belt',(0,0,.71),(.53,.37,.09),'leather');b('Bone clasp',(0,-.2,.72),(.12,.04,.12),'bone')
 ball('Oversized head',(0,-.06,1.42),(.29,.25,.32),skin,'Head')
 ball('Long pointed nose',(0,-.34,1.42),(.1,.22,.095),'goblin_light' if not troll else 'troll','Head')
 b('Lower lip',(0,-.27,1.25),(.29,.11,.095),skin,'Head',.035)
 b('Mouth',(0,-.293,1.31),(.27,.025,.055),'dark','Head',.01)
 for side in [-1,1]:
  ear=cone('Swept pointed ear',p((side*.36,-.03,1.48)),.145*s,0,.45*s,skin,'Head',vertices=5);ear.rotation_euler.y=side*1.1
  ball('Eye socket',(side*.135,-.27,1.50),(.108,.055,.09),'dark','Head')
  ball('Golden eye',(side*.135,-.315,1.50),(.075,.025,.05),'gold','Head')
  ball('Pupil',(side*.135,-.337,1.50),(.022,.015,.033),'dark','Head')
  b('Heavy brow',(side*.13,-.29,1.58),(.24,.1,.07),skin,'Head',.025).rotation_euler.y=side*.22
  cone('Tusks',p((side*.11,-.33,1.34)),.038*s,0,.15*s,'bone','Head',vertices=6)
  arm='Arm_L' if side<0 else 'Arm_R';leg='Leg_L' if side<0 else 'Leg_R'
  ball('Shoulder',(side*.34,0,1.04),(.17,.17,.2),skin,arm)
  beam('Forearm',p((side*.39,-.01,.99)),p((side*.42,-.08,.65)),.10*s,skin,arm)
  ball('Knuckled hand',(side*.42,-.09,.65),(.13,.12,.12),skin,arm)
  b('Wrist strap',(side*.415,-.06,.78),(.21,.23,.08),'leather',arm)
  b('Short trousers',(side*.15,0,.48),(.21,.26,.36),'leather',leg)
  b('Wrapped boots',(side*.17,-.06,.16),(.24,.35,.25),'dark',leg)
  for z in [.25,.33]:b('Leg bindings',(side*.17,-.145,z),(.24,.05,.04),'rope',leg)
  if armor:
   b('Scrap shoulder plate',(side*.37,0,1.16),(.30,.32,.12),'steel',arm)
   for j in [-1,1]:cone('Shoulder spike',p((side*.37,j*.09,1.29)),.048*s,0,.23*s,'bone',arm,vertices=5)
 if kind=='goblin_worker':
  b('Gathering satchel',(.23,.25,.8),(.27,.17,.3),'plank')
  shaft=beam('Axe_CTRL',p((.43,-.12,.51)),p((.43,-.12,1.02)),.035*s,'wood','Arm_R')
  head=b('Axe blade',(.5,-.12,1.02),(.23,.09,.18),'steel','Arm_R');join_objects([shaft,head],'Axe_CTRL')
  hammer=beam('Hammer_CTRL',p((.43,-.12,.51)),p((.43,-.12,1.04)),.035*s,'wood','Arm_R')
  h=b('Hammer head',(.43,-.12,1.04),(.31,.15,.16),'stone','Arm_R');join_objects([hammer,h],'Hammer_CTRL')
 elif kind in ('goblin_archer','spider_rider'):
  before=set(bpy.context.scene.objects);bow('Arm_L',-.49)
  for obj in set(bpy.context.scene.objects)-before:obj.location.z+=lift
  b('Quiver',(.15,.25,1.02),(.22,.16,.45),'leather')
  for x in [.07,.15,.23]:beam('Arrow in quiver',p((x,.26,1.12)),p((x,.26,1.52)),.012*s,'plank','Body')
 elif kind=='goblin_spearman':
  beam('Long spear',p((.43,-.1,.25)),p((.43,-.1,2.1)),.035*s,'wood','Arm_R')
  cone('Leaf spearhead',p((.43,-.1,2.28)),.10*s,0,.40*s,'steel','Arm_R',vertices=4)
 elif troll:
  beam('Great club',p((.43,-.1,.4)),p((.46,-.1,1.28)),.09*s,'wood','Arm_R')
  b('Iron-bound club head',(.46,-.1,1.42),(.33,.33,.45),'wood','Arm_R')
  for z in [1.24,1.5]:b('Iron club band',(.46,-.1,z),(.36,.36,.07),'steel','Arm_R')
 else:
  b('Cleaver',(.43,-.1,.96),(.24,.06,.54),'steel','Arm_R')
  beam('Cleaver grip',p((.43,-.1,.56)),p((.43,-.1,.77)),.044*s,'wood','Arm_R')
  b('Shield',(-.48,-.17,.83),(.12,.41,.48),'plank','Arm_L')
  ball('Shield boss',(-.55,-.17,.85),(.10,.13,.13),'steel','Arm_L')
 pivots={'Body':p((0,0,.72)),'Head':p((0,0,1.25)),'Arm_L':p((-.34,0,1.13)),'Arm_R':p((.34,0,1.13)),'Leg_L':p((-.16,0,.65)),'Leg_R':p((.16,0,.65))}
 if rider:
  ico('Spider abdomen',(0,.47,.5),(.52,.62,.36),'wolf_dark','Body',2);ico('Spider carapace',(0,-.30,.48),(.42,.46,.25),'moss','Body',2)
  box('Saddle',(0,.0,.76),(.48,.5,.14),'leather','Body')
  for i in range(4):
   for side in [-1,1]:
    bone='Spider'+str(i*2+(side>0));a=(side*.28,.40-i*.23,.50);b=(side*.89,.66-i*.40,.63);c=(side*1.25,.85-i*.55,.045)
    beam('Chitin thigh',a,b,.075,'wolf_dark',bone);beam('Chitin shin',b,c,.045,'dark',bone);ico('Knee',b,(.1,.1,.1),'moss',bone)
    pivots[bone]=a
  for x in [-.18,-.06,.06,.18]:ico('Spider amber eyes',(x,-.67,.5),(.04,.035,.045),'eyes','Body')
 # Tools joined above replace individual mesh references in the skinning groups.
 for bone in parts:
  valid=[]
  for o in parts[bone]:
   try:
    if o.name in bpy.data.objects:valid.append(o)
   except ReferenceError:pass
  parts[bone]=valid
 rig_custom(kind,pivots);export(kind,True)

def banner(x,y,z,gob=True):
 beam('Banner pole',(x,y,0),(x,y,z+.8),.035,'wood')
 box('Tribal standard' if gob else 'Harbor flag',(x+.24,y,z+.44),(.48,.035,.62),'tribal' if gob else 'cloth')
 ico('Company emblem',(x+.24,y-.04,z+.48),(.10,.028,.13),'bone',sub=1)
def spikes(w,d):
 for x in [-w/2,w/2]:
  for y in [-d/2,0,d/2]:cone('Sharpened stakes',(x,y,.75),.075,.01,1.5,'wood',vertices=6)
def building(kind):
 clear();gob=kind.startswith('goblin_');name=kind.removeprefix('goblin_');w,d=(3,2) if name=='port' else ((3,3) if name in ('barracks','workshop','farm') else (2,2))
 if name=='wall':w,d=1,1
 if name=='gate':w,d=2,1
 if name=='port':
  for y in [-.85,-.5,-.15,.2,.55,.9]:box('Dock planks',(0,y,.20),(3,.3,.12),'plank')
  for x in [-1.35,1.35]:
   for y in [-.75,.75]:beam('Mooring pile',(x,y,-.5),(x,y,1),.13,'wood');cone('Rope bollard',(x,y,1),.16,.16,.12,'rope')
  for y in [-.6,-.25,.1,.45]:box('Landing finger',(0,y+1.5,.17),(1.0,.3,.13),'wood')
  for x in [-.55,.55]:beam('Hoist support',(x,-.1,.2),(x,-.1,2.5),.10,'wood')
  beam('Crane boom',(-.9,-.1,2.45),(.9,-.1,2.45),.11,'wood');beam('Hoist rope',(.65,-.1,2.4),(.65,-.1,.8),.018,'rope')
  for x in [-1,1]:crate((x,-.5,.5),.48)
  banner(-1.1,.7,2.2,gob)
 elif name=='farm':
  box('Mushroom bed',(0,0,.10),(2.9,2.9,.2),'wood')
  for x in [-1,-.5,0,.5,1]:
   for y in [-1,-.4,.2,.8]:
    beam('Crop stem',(x,y,.2),(x,y,.57),.025,'bone');ico('Crop cap',(x,y,.64),(.16,.15,.10),'tribal_light',sub=2)
  crops=join_objects([o for o in bpy.context.scene.objects if o.name.startswith('Crop')],'CropPlants');bpy.context.scene.cursor.location=(0,0,.2);bpy.context.view_layer.objects.active=crops;bpy.ops.object.origin_set(type='ORIGIN_CURSOR');spikes(2.8,2.8)
 elif name in ('wall','gate'):
  for x in [-w/2+.13+i*.26 for i in range(round(w/.26))]:
   if name=='gate' and abs(x)<.6:continue
   cone('Crooked palisade',(x,0,.86),.14,.015,1.72,'wood',vertices=6)
  if name=='gate':box('GateDoor',(0,0,.8),(1.4,.16,1.5),'tribal');banner(-.86,0,1.4)
 elif name=='tower':
  for x,y in [(-.7,-.7),(.7,-.7),(0,.7)]:
   beam('Tripod tower foot',(x,y,0),(x*.7,y*.7,2.8),.13,'wood')
  box('Lookout platform',(0,0,2.55),(1.6,1.6,.16),'plank')
  cone('Hide canopy',(0,0,3.3),1.05,0,.65,'tribal',vertices=7);banner(.7,.5,3.2)
  for i in range(7):beam('Ladder rung',(-.3,-.8,.25+i*.3),(.3,-.8,.25+i*.3),.025,'rope')
 elif name=='well':
  for i in range(10):
   a=i*math.tau/10;box('Well stones',(math.cos(a)*.55,math.sin(a)*.55,.38),(.34,.28,.76),'stone')
  for x in [-.7,.7]:beam('Bone hoist',(x,0,0),(x,0,1.9),.09,'bone')
  beam('Cross beam',(-.8,0,1.7),(.8,0,1.7),.08,'wood');beam('Rope',(0,0,.4),(0,0,1.7),.02,'rope');cone('Bucket',(.7,-.6,.2),.15,.18,.3,'wood')
 elif name=='mine':
  box('Mine opening',(0,0,.06),(1.6,1.4,.1),'dark')
  for x in [-.75,.75]:beam('Timber shoring',(x,0,0),(x,0,1.6),.13,'wood')
  beam('Shoring lintel',(-.9,0,1.6),(.9,0,1.6),.15,'wood');ico('DeepOreBlock',(-.5,-.5,.45),(.2,.2,.25),'eyes',sub=1)
  for x in [-.4,.1,.5]:ico('Ore rubble',(x,.5,.18),(.25,.3,.2),'stone',sub=1)
 elif name=='campfire':
  for i in range(9):
   a=i*math.tau/9;ico('Hearth stone',(math.cos(a)*.5,math.sin(a)*.5,.17),(.2,.2,.17),'stone',sub=1)
  cone('Totem',(0,.4,1.05),.22,.14,2.1,'wood',vertices=6)
  for z in [.75,1.2,1.65]:
   box('Carved mask',(0,.20,z),(.4,.1,.25),'bone');ico('Totem eyes',(-.1,.13,z+.03),(.045,.04,.04),'ember');ico('Totem eyes',(.1,.13,z+.03),(.045,.04,.04),'ember')
  ico('Fire',(0,-.1,.42),(.28,.3,.4),'ember',sub=1);banner(.8,.6,1.4)
 elif name=='storage':
  for x in [-.55,.1,.7]:
   crate((x,0,.38),.6);cone('Barrel',(x,.65,.37),.25,.25,.7,'wood',vertices=10)
  for x in [-.85,.85]:beam('Rack',(x,-.5,0),(x,-.5,1.65),.07,'wood')
  box('Store canopy',(0,0,1.55),(1.9,1.6,.1),'tribal');banner(.85,.65,1.2)
 elif name in ('barracks','workshop'):
  box('Training deck',(0,0,.10),(2.9,2.9,.2),'plank');spikes(2.7,2.7)
  for x in [-1.05,1.05]:beam('Hall pillars',(x,.55,.15),(x,.55,2.2),.11,'wood')
  cone('Patchwork war tent',(0,.55,1.83),1.2,0,1.05,'tribal',vertices=6)
  for x in [-.9,-.45,0,.45,.9]:beam('Spear rack',(x,.9,.2),(x,.9,1.55),.025,'wood');cone('Rack spearhead',(x,.9,1.67),.07,0,.24,'steel',vertices=4)
  for x in [-.75,.75]:
   beam('Dummy post',(x,-.55,.2),(x,-.55,1.25),.05,'wood');ico('Training effigy',(x,-.55,.95),(.23,.16,.3),'rope',sub=1)
  banner(-1.2,.8,2.3)
 else:
  cone('Round hut walls',(0,0,.6),.83,.76,1.2,'plank',vertices=10)
  cone('Stitched hide roof',(0,0,1.45),1.10,0,.85,'tribal',vertices=10)
  box('Doorway',(0,-.79,.5),(.50,.08,.9),'dark')
  for side in [-1,1]:beam('Door tusk',(side*.3,-.8,0),(side*.26,-.8,1.05),.055,'bone')
  for i in range(10):
   a=i*math.tau/10;beam('Roof seam',(math.cos(a)*1.02,math.sin(a)*1.02,1.08),(0,0,1.87),.014,'rope')
 export(kind)

def ship(kind):
 clear();galley=kind=='galley';length=4.6 if galley else 2.7;width=1.35 if galley else .95
 verts=[]
 for z,scale in [(-.18,.55),(.08,1),(.52,1.08)]:
  for x,y in [(-width*.35,-length*.5),(width*.35,-length*.5),(width*.5,-length*.30),(width*.5,length*.35),(width*.22,length*.5),(-width*.22,length*.5),(-width*.5,length*.35),(-width*.5,-length*.30)]:verts.append((x*scale,y,z))
 faces=[]
 for ring in range(2):
  for i in range(8):faces.append((ring*8+i,ring*8+(i+1)%8,(ring+1)*8+(i+1)%8,(ring+1)*8+i))
 faces.append(tuple(range(7,-1,-1)))
 mesh=bpy.data.meshes.new('Planked hull');mesh.from_pydata(verts,[],faces);mesh.materials.append(M['wood']);obj=bpy.data.objects.new('Hull',mesh);bpy.context.collection.objects.link(obj)
 for y in [(-length*.38)+i*.20 for i in range(int(length*.76/.2))]:box('Deck plank',(0,y,.15),(width*.82,.18,.08),'plank',bevel=.008)
 for x in [-width*.48,width*.48]:
  beam('Gunwale',(x,-length*.28,.5),(x,length*.32,.5),.045,'gold')
  for i in range(6 if galley else 2):
   y=-length*.25+i*(.42 if galley else .8);beam('Oar',(x*.6,y,.3),(x*2.25,y+.2,-.02),.025,'wood');box('Oar blade',(x*2.3,y+.2,-.015),(.28,.13,.035),'plank',bevel=.005)
 for y in [-.6,.3,.9] if galley else [-.3,.35]:box('Bench',(0,y,.39),(width*.9,.19,.10),'wood')
 mast_h=3.1 if galley else 2.1
 beam('Mast',(0,-.2,.2),(0,-.2,mast_h),.055,'wood');beam('Yard',(-width*.9,-.2,mast_h-.25),(width*.9,-.2,mast_h-.25),.035,'wood')
 # Curved billowing sail with sewn vertical panels.
 for panel in range(8):
  x0=-width*.85+panel*width*1.7/8;x1=x0+width*1.7/8
  points=[]
  for z in [mast_h-1.5,mast_h-.9,mast_h-.3]:
   for x in [x0,x1]:points.append((x,-.25-.24*math.sin((z-mast_h+1.5)/1.2*math.pi),z))
  me=bpy.data.meshes.new('Sail panel');me.from_pydata(points,[],[(0,1,3,2),(2,3,5,4)]);me.materials.append(M['sail' if panel%2==0 else 'birch']);o=bpy.data.objects.new('Canvas sail',me);bpy.context.collection.objects.link(o)
 for x in [-width*.42,width*.42]:beam('Standing rigging',(x,.8,.2),(0,-.2,mast_h-.1),.012,'rope')
 box('Rudder',(0,length*.49,.1),(.07,.36,.50),'wood');crate((0,length*.28,.35),.35)
 export(kind)

def build(name):
 if name in ('wolf','bear'):animal(name)
 elif name in ('boat','galley'):ship(name)
 elif name=='carcass':
  clear();ico('Hide',(0,0,.15),(.49,.31,.17),'leather',sub=2);ico('Meat',(0,-.02,.23),(.36,.23,.16),'meat',sub=2)
  for x in [-.24,-.08,.08,.24]:beam('Rib',(x,-.18,.23),(x,.18,.29),.022,'bone')
  export(name)
 elif name.startswith('goblin_') and name.split('_',1)[1] in ['worker','warrior','archer','spearman'] or name in ('troll','spider_rider'):goblin(name)
 else:building(name)
 print('ARCHIPELAGO ASSET EXPORTED:',name)
