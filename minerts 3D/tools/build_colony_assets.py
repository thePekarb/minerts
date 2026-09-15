"""Additional themed buildings and huntable wildlife, authored in Blender."""
from pathlib import Path
source=Path(__file__).with_name('build_frontier_assets.py').read_text()
exec(source[:source.index("for kind in ['worker'")])
clear()
# Barracks: fortified open training court, crenellations, armory, weapon racks.
box('Stone foundation',(0,0,.12),(2.85,2.85,.24),'stone')
for x in (-1.3,1.3):
 box('Curtain wall',(x,0,.7),(.22,2.8,1.1),'stone')
 for y in (-1.2,-.6,0,.6,1.2):box('Crenellation',(x,y,1.39),(.29,.30,.36),'stone')
box('Back wall',(0,1.3,.7),(2.8,.22,1.1),'stone')
for x in (-1.1,-.55,0,.55,1.1):box('Crenellation',(x,1.3,1.39),(.28,.27,.36),'stone')
for x in (-.93,.93):
 box('Gate tower',(x,-1.15,1),(.66,.65,2),'stone')
 for xx in (-.2,.2):box('Tower merlon',(x+xx,-1.15,2.16),(.22,.7,.32),'stone')
 box('Company banner',(x,-1.495,1.27),(.34,.03,.75),'cloth')
 box('Emblem',(x,-1.52,1.3),(.09,.02,.42),'gold')
box('Entrance lintel',(0,-1.15,1.55),(1.25,.2,.17),'wood')
box('Armory',(0,.9,1), (1.35,.60,1.5),'wood')
roof(1.4,.65,1.7)
for y in (-.6,0,.6):
 beam('Weapon rack',(-1.0,y,.15),(-1.0,y,1.1),.04,'wood')
 beam('Spear',(-.87,y,.3),(-.87,y,1.45),.025,'plank')
 cone('Spear point',(-.87,y,1.53),.07,0,.16,'steel',vertices=4)
for x in (.3,.8):
 beam('Dummy post',(x,0,.1),(x,0,1.15),.06,'wood')
 ico('Training dummy',(x,0,.8),(.2,.17,.3),'endgrain')
 beam('Dummy arms',(x-.3,0,.93),(x+.3,0,.93),.06,'wood')
export('barracks')
clear()
box('Cultivated soil',(0,0,.08),(2.9,2.9,.16),'wood')
for x in (-1.32,-.88,-.44,0,.44,.88,1.32):
 box('Raised bed',(x,0,.19),(.27,2.7,.16),'leather')
 for y in (-1.1,-.7,-.3,.1,.5,.9):
  beam('Wheat stem',(x,y,.27),(x,y,.79),.016,'grass')
  ico('Wheat ear',(x,y,.82),(.058,.055,.16),'gold')
for x in (-1.47,1.47):
 for y in (-1.47,1.47):box('Fence post',(x,y,.43),(.08,.08,.86),'wood')
 beam('Fence',(x,-1.47,.54),(x,1.47,.54),.035,'plank')
crops=join_objects([o for o in bpy.context.scene.objects if o.name.startswith('Wheat')], 'CropPlants')
bpy.context.scene.cursor.location=(0,0,.27)
bpy.ops.object.select_all(action='DESELECT');crops.select_set(True);bpy.context.view_layer.objects.active=crops
bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
export('farm')
clear()
for i in range(12):
 a=i*math.tau/12;o=box('Well masonry',(math.cos(a)*.57,math.sin(a)*.57,.5),(.33,.25,1),'stone');o.rotation_euler.z=a
cone('Water',(0,0,.55),.44,.44,.03,'cloth',vertices=16)
for x in (-.72,.72):beam('Support',(x,0,0),(x,0,1.9),.09,'wood')
roof(1.7,1.5,1.85)
beam('Spindle',(-.8,0,1.35),(.8,0,1.35),.08,'wood')
beam('Bucket rope',(0,0,.6),(0,0,1.4),.015,'endgrain')
cone('Bucket',(.3,-.63,.22),.15,.19,.36,'plank')
export('well')
for kind in ['deer','boar','rabbit']:
 clear();r=.48 if kind=='deer' else (.38 if kind=='boar' else .20)
 color='plank' if kind=='deer' else ('leather' if kind=='boar' else 'birch')
 ico('Body',(0,.12,r+(.25 if kind=='deer' else .06)),(r*.7,r*1.3,r*.7),color,'Body',2)
 ico('Head',(0,-r*.9,r*1.6),(r*.48,r*.65,r*.5),color,'Head',2)
 for side in (-1,1):
  for front in (-1,1):
   bone='Leg_L' if side<0 else 'Leg_R'
   beam('Leg',(side*r*.4,front*r*.6,.12),(side*r*.4,front*r*.6,r+.18),r*.10,color,bone)
  ico('Eye',(side*r*.37,-r*1.32,r*1.75),(.028,.02,.028),'dark','Head')
  ico('Ear',(side*r*.3,-r*.65,r*(2.15 if kind!='rabbit' else 2.8)),(r*.15,r*.15,r*(.28 if kind!='rabbit' else .85)),color,'Head')
  if kind=='deer':
   beam('Antler',(side*.13,-.3,.9),(side*.27,-.2,1.45),.025,'bone','Head')
   beam('Antler tine',(side*.19,-.23,1.2),(side*.40,-.23,1.37),.02,'bone','Head')
  if kind=='boar':cone('Tusk',(side*.13,-.55,.51),.035,0,.19,'bone','Head',vertices=5)
 rig_character(kind)
 export(kind,animated=True)
print('COLONY ASSETS COMPLETE')
