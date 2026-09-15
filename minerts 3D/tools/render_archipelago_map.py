"""Render the actual terrain data as a labeled overview (requires Pillow)."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[1]
data=json.loads((ROOT/'assets/frontier/island.json').read_text());n=data['size']
terrain=Image.new('RGB',(n,n));pixels=terrain.load()
colors=[(133,161,98),(71,115,89),(139,143,133),(213,196,144),(24,57,70),(210,221,218),(94,131,111)]
for z in range(n):
 for x in range(n):
  i=z*n+x;h=data['heights'][i];color=colors[data['biomes'][i]]
  shade=1 if not h else 1+max(-.3,min(.25,(h-data['heights'][max(0,z-1)*n+max(0,x-1)])*.12))
  pixels[x,z]=tuple(min(255,int(c*shade)) for c in color)
canvas=Image.new('RGB',(1184,1260),(13,30,38));canvas.paste(terrain.resize((1024,1024),Image.Resampling.NEAREST),(80,144));draw=ImageDraw.Draw(canvas)
font='/System/Library/Fonts/Supplemental/Arial.ttf'
large=ImageFont.truetype(font,34);small=ImageFont.truetype(font,20);label=ImageFont.truetype(font,23)
draw.text((80,42),'FRONTIER / АРХИПЕЛАГ',font=large,fill='#ead9ad')
draw.text((80,94),'512 × 512 клеток · 6 островов · обзор без тумана войны',font=small,fill='#99b6bd')
labels=['Домашний остров','Корона моря','Поселение гоблинов','Кедровый остров','Угольный атолл','Туманный лес']
for island,name in zip(data['islands'],labels):
 x,z=island['center'];pos=(80+x*2,144+z*2)
 box=draw.textbbox(pos,name,font=label,anchor='mm');pad=10
 draw.rounded_rectangle((box[0]-pad,box[1]-pad,box[2]+pad,box[3]+pad),radius=6,fill='#142d36',outline='#748c87')
 draw.text(pos,name,font=label,fill='#f0e7cb',anchor='mm')
for x,z in data['treasures']:
 px,pz=80+x*2,144+z*2
 draw.rectangle((px-4,pz-4,px+4,pz+4),fill='#f3bc59',outline='#533f24')
draw.text((80,1203),'Золотые метки — сундуки центрального острова',font=small,fill='#d7be83')
canvas.save(ROOT/'art/archipelago-map.png')
