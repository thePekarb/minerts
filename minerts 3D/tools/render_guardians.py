import bpy, math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
rows=[['ancient_golem','storm_warden']]
for row,items in enumerate(rows):
 for col,name in enumerate(items):
  before=set(bpy.context.scene.objects);bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/frontier'/f'{name}.glb'))
  new=set(bpy.context.scene.objects)-before
  for o in new:
   if o.parent is None:o.location+=Vector((col*4.8-2.4,row*4.8,0))
  bpy.ops.object.text_add(location=(col*4.8-2.4,row*4.8-1.4,.025));t=bpy.context.object;t.data.body=name.replace('tree_','').replace('prop_','').upper();t.data.align_x='CENTER';t.data.size=.22
bpy.ops.mesh.primitive_plane_add(size=200);plane=bpy.context.object;plane.location.z=-.06
m=bpy.data.materials.new('Gallery ground');m.diffuse_color=(.10,.16,.17,1);plane.data.materials.append(m)
world=bpy.context.scene.world;world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.32,.42,.48,1);world.node_tree.nodes['Background'].inputs[1].default_value=.55
bpy.ops.object.light_add(type='AREA',location=(-8,-6,18));bpy.context.object.data.energy=2200;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=12
bpy.ops.object.camera_add(location=(7,-13,10));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,1.0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=10;bpy.context.scene.camera=cam
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=20;s.cycles.use_denoising=True;s.render.resolution_x=1400;s.render.resolution_y=1000;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.render.filepath=str(ROOT/'art/guardians.png')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/guardians-gallery.blend'));bpy.ops.render.render(write_still=True)
