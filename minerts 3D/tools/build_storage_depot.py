"""Build an open warehouse with independent stock meshes for runtime fill levels."""
import bpy, math, random
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def mat(name,color):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);return m
def cube(name,loc,scale,material,parent=None,bevel=.018):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.dimensions=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(material)
 if bevel:
  mod=o.modifiers.new('Soft timber edges','BEVEL');mod.width=bevel;mod.segments=1;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
 o.parent=parent;return o
def cylinder(name,loc,r,depth,material,parent=None,rotation=(0,0,0),vertices=10):
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=depth,location=loc,rotation=rotation);o=bpy.context.object;o.name=name;o.data.materials.append(material);o.parent=parent;return o
def ico(name,loc,scale,material,parent=None):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=loc);o=bpy.context.object;o.name=name;o.scale=scale;o.data.materials.append(material);o.parent=parent;return o
def empty(name):
 o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);return o
for faction in ['player','goblin']:
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 wood=mat('Timber_'+faction,(.30,.18,.10) if faction=='player' else (.22,.24,.10));plank=mat('Boards_'+faction,(.49,.32,.17));iron=mat('Iron_'+faction,(.15,.21,.23));roof=mat('Awning_'+faction,(.16,.37,.47) if faction=='player' else (.39,.26,.18))
 stone=mat('Stone_'+faction,(.44,.49,.53));sand=mat('Sacks_'+faction,(.69,.53,.28));fruit=mat('Harvest_'+faction,(.70,.22,.10));cut=mat('Endgrain_'+faction,(.65,.45,.25))
 for x in [-.94,.94]:cube('Foundation',(x,0,.06),(.12,1.95,.12),stone)
 for j in range(11):cube('Floor plank',(0,-.85+j*.17,.15),(1.94,.16,.1),plank,bevel=.009)
 for x in [-.94,.94]:
  for y in [-.89,.89]:
   cube('Post',(x,y,.91),(.12,.12,1.65),wood)
   for z in [.25,1.48]:cube('Forged strap',(x,y,z),(.14,.14,.05),iron,bevel=.005)
 for x in [-.96,-.32,.32,.96]:
  for z in [.38,.63,.88]:cube('Bay divider',(x,0,z),(.065,1.85,.18),plank,bevel=.01)
 for y in [-.92,.92]:
  for z in [.38,.68]:cube('Front rails',(0,y,z),(1.98,.07,.13),wood)
 for z in [.95,1.17,1.38]:cube('Rear boards',(0,-.92,z),(1.94,.06,.19),plank)
 for x in [-.66,0,.66]:
  brace=cube('Diagonal braces',(x,-.97,1.05),(.065,.05,.65),wood);brace.rotation_euler[1]=.45
 for x in [-.94,.94]:cube('Awning beam',(x,-.55,1.64),(.13,.95,.1),wood)
 for j in range(9):
  tile=cube('Awning panel',(-.96+j*.24,-.64,1.75),(.25,.76,.05),roof);tile.rotation_euler[0]=.12
 # Individual stock groups remain separately hideable; static pieces are joined to one mesh.
 for i,key in enumerate(['food','wood','stone']):
  for n in range(9):
   group=empty('Stock_'+key+'_'+str(n))
   x=-.64+i*.64+(-.14 if n%2==0 else .14);y=-.34+(n%4//2)*.58;z=.31+(n//4)*.26
   if key=='wood':
    cylinder('Bark',(x,y,z),.105,.48,wood,group,(math.pi/2,0,0))
    for end in [-.247,.247]:cylinder('Cut rings',(x,y+end,z),.083,.008,cut,group,(math.pi/2,0,0))
   elif key=='stone':
    rock=ico('Quarried stone',(x,y,z),(.13,.16,.13),stone,group);rock.rotation_euler[2]=n*.63
   else:
    ico('Grain sack',(x,y,z),(.12,.14,.15),sand,group);cylinder('Sack tie',(x,y,z+.14),.035,.05,wood,group)
    if n%2==0:ico('Red produce',(x+.06,y-.05,z+.12),(.045,.045,.045),fruit,group)
 # Join static frame to reduce draws, without flattening the stock groups.
 bpy.ops.object.select_all(action='DESELECT')
 parts=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.parent is None]
 for o in parts:o.select_set(True)
 bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();bpy.context.object.name='WarehouseFrame'
 for parent in [o for o in bpy.context.scene.objects if o.type=='EMPTY']:
  children=[o for o in parent.children if o.type=='MESH']
  bpy.ops.object.select_all(action='DESELECT')
  for o in children:o.select_set(True)
  if children:
   bpy.context.view_layer.objects.active=children[0];bpy.ops.object.join();bpy.context.object.name='Cargo'
 dest=ROOT/'assets/frontier'/('storage_depot_'+faction+'.glb')
 bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender'/('storage_depot_'+faction+'.blend')))
 bpy.ops.export_scene.gltf(filepath=str(dest),export_format='GLB',export_yup=True,export_cameras=False,export_lights=False)
 print('EXPORTED',dest)
