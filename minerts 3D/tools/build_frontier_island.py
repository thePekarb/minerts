"""Blender-authored stepped island; exports editable mesh + runtime height/biome data."""
import bpy, math, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];N=192;C=96
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
heights=[];biomes=[];verts=[];faces=[];face_biomes=[]
colors=[(.36,.49,.26,1),(.24,.39,.24,1),(.46,.49,.47,1),(.72,.67,.47,1),(.12,.34,.40,1),(.79,.84,.80,1),(.32,.43,.34,1)]
materials=[]
for name,col in zip(['Meadow','Forest','Slate cliffs','Sand','Water bed','Alpine snow','Wetland'],colors):
 m=bpy.data.materials.new(name);m.diffuse_color=col;materials.append(m)
for z in range(N):
 for x in range(N):
  dx,dz=x-C,z-C;r=math.hypot(dx,dz);angle=math.atan2(dz,dx)
  coast=82+5*math.sin(angle*3+.8)+3*math.sin(angle*7)
  continental=max(0,min(1,(coast-r)/16))
  hills=3.1+1.15*math.sin(x*.074+math.sin(z*.043))*math.cos(z*.062)+.65*math.sin(x*.17+z*.073)
  ridge=8.5*math.exp(-((dx+31)/18)**2-((dz-27)/36)**2)+6.7*math.exp(-((dx-39)/21)**2-((dz+27)/21)**2)
  h=round((hills+ridge)*continental)
  # A curving river in the eastern lowlands; shallow marsh edges and a lake.
  river=abs(dx-(43+8*math.sin(dz*.055)))
  lake=((dx+33)/11)**2+((dz+28)/8)**2
  if (river<1.5 and -12<dz<75) or lake<1:h=0
  elif river<3.5 and -12<dz<75:h=min(h,1)
  if r<10:h=2
  elif r<17:h=round(2+(h-2)*(r-10)/7)
  # Four traversable approach valleys link the base and altar plateaus.
  if (abs(dx)<3 and abs(dz)<61) or (abs(dz)<3 and abs(dx)<61):h=2+round(min(1,max(abs(dx),abs(dz))/58)*3)
  for ax,az in [(96,38),(154,96),(96,154),(38,96)]:
   if abs(x-ax)<=3 and abs(z-az)<=3:h=5
  h=max(0,min(13,h));heights.append(h)
  moisture=math.sin(x*.067+1.4)*math.cos(z*.049)+.28*math.sin(z*.19)
  b=4 if h==0 else (3 if h==1 else (5 if h>=10 else (2 if h>=6 else (6 if river<5 and -12<dz<75 else (1 if moisture>.05 else 0)))))
  if r<11:b=0
  biomes.append(b)
# Build the exact stepped surface represented by the runtime heightfield.
def face(points,b):
 i=len(verts);verts.extend(points);faces.append(tuple(range(i,i+4)));face_biomes.append(b)
for z in range(N):
 for x in range(N):
  h=heights[z*N+x];b=biomes[z*N+x]
  face([(x,-z,h),(x+1,-z,h),(x+1,-z-1,h),(x,-z-1,h)],b)
  for nx,nz,edge in [(x+1,z,[(x+1,-z-1),(x+1,-z)]),(x-1,z,[(x,-z),(x,-z-1)]),(x,z+1,[(x,-z-1),(x+1,-z-1)]),(x,z-1,[(x+1,-z),(x,-z)])]:
   nh=heights[nz*N+nx] if 0<=nx<N and 0<=nz<N else 0
   if nh<h:
    a,c=edge;face([(*a,h),(*c,h),(*c,nh),(*a,nh)],2 if h>3 else b)
mesh=bpy.data.meshes.new('Island terraces');mesh.from_pydata(verts,[],faces);mesh.update()
o=bpy.data.objects.new('Frontier Island 192',mesh);bpy.context.collection.objects.link(o)
for m in materials:mesh.materials.append(m)
for poly,b in zip(mesh.polygons,face_biomes):poly.material_index=b
bpy.context.view_layer.objects.active=o;o.select_set(True)
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/island.blend'))
(ROOT/'assets/frontier/island.json').write_text(json.dumps({'size':N,'seed':1337,'heights':heights,'biomes':biomes},separators=(',',':')))
print('ISLAND COMPLETE',N,'height range',min(heights),max(heights))
