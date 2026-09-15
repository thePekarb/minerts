"""Six connected landmasses separated by navigable sea; preserves the home island."""
from pathlib import Path
import json, math
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/frontier'
source=OUT/'home_island.json'
if not source.exists(): source.write_text((OUT/'island.json').read_text())
home=json.loads(source.read_text()); size=512
heights=[0]*(size*size); biomes=[4]*(size*size)
for z in range(home['size']):
 for x in range(home['size']):
  i=z*size+x;j=z*home['size']+x
  heights[i]=home['heights'][j];biomes[i]=home['biomes'][j]
islands=[dict(id='home',name='Frontier',center=[96,96],radius=82),dict(id='crown',name='Crown of the Sea',center=[300,280],radius=113),dict(id='goblin',name='Brambleclaw',center=[402,80],radius=57),dict(id='cedar',name='Cedar Reach',center=[86,411],radius=67),dict(id='ember',name='Ember Atoll',center=[445,437],radius=43),dict(id='mist',name='Mistwood',center=[47,251],radius=35)]
for n,land in enumerate(islands[1:],1):
 cx,cz=land['center'];r=land['radius']
 for z in range(max(2,cz-r-4),min(size-2,cz+r+5)):
  for x in range(max(2,cx-r-4),min(size-2,cx+r+5)):
   dx=x-cx;dz=z-cz;d=math.hypot(dx,dz);angle=math.atan2(dz,dx)
   edge=r*(.94+.035*math.sin(angle*5+n)+.022*math.cos(angle*9))
   if d>=edge:continue
   inland=edge-d
   noise=.55*math.sin(x*.073+n)*math.cos(z*.065)+.28*math.sin((x+z)*.13)
   h=1 if inland<4 else 2+max(0,round((1-d/edge)*8+noise*2))
   # Natural radial low passes allow colonies to reach every coast.
   if abs(dx)<=3 or abs(dz)<=3:
    h=min(h,1+int(inland/10))
   if land['id']=='goblin' and abs(dx)<=18 and abs(dz)<=18:h=2
   biome=3 if h==1 else (5 if h>=9 else (2 if h>=6 else (1 if noise>-.12 else 0)))
   i=z*size+x;heights[i]=h;biomes[i]=biome
 # The settlement clearing has broad one-step access ramps.
 if land['id']=='goblin':
  for z in range(cz-23,cz+24):
   for x in range(cx-23,cx+24):
    d=max(abs(x-cx),abs(z-cz)); i=z*size+x
    heights[i]=min(heights[i],2+max(0,(d-18)//3));biomes[i]=0 if d<19 else biomes[i]
# Keep only land reachable from the six island centres, removing isolated slivers.
seen=set()
for land in islands:
 todo=[tuple(land['center'])];seen.add(todo[0])
 while todo:
  x,z=todo.pop()
  for dx,dz in ((1,0),(-1,0),(0,1),(0,-1)):
   p=(x+dx,z+dz)
   if 0<=p[0]<size and 0<=p[1]<size and p not in seen and heights[p[1]*size+p[0]]>0:
    seen.add(p);todo.append(p)
for z in range(size):
 for x in range(size):
  if heights[z*size+x] and (x,z) not in seen:heights[z*size+x]=0;biomes[z*size+x]=4
result=dict(size=size,seed=1337,heights=heights,biomes=biomes,islands=islands,player_spawn=[96,96],goblin_spawn=[402,80],treasures=[[282,270],[322,296],[293,314],[270,291],[327,259]])
(OUT/'island.json').write_text(json.dumps(result,separators=(',',':')))
print('ARCHIPELAGO:',size,'x',size,'six islands;',len(seen),'land cells')
