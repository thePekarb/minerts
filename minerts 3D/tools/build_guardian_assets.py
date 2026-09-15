"""Editable, rigged guardians of the central island. Run with Blender -b -P."""
from pathlib import Path
exec(compile(Path(__file__).with_name('build_archipelago_assets.py').read_text(),str(Path(__file__).with_name('build_archipelago_assets.py')),'exec'))
mat('ancient','65746b');mat('ancient_edge','98a890');mat('rune','8edbc2',0,3);mat('storm','333951');mat('storm_gold','bba66b',.65);mat('lightning','8bdcff',0,3)
for name in ['ancient_golem','storm_warden']:
 clear();golem=name=='ancient_golem'
 if golem:
  box('Monolithic chest',(0,0,1.52),(1.03,.62,.88),'ancient','Body',.10)
  box('Waist stones',(0,0,.96),(.67,.50,.25),'dark','Body',.06)
  ico('Moss collar',(0,0,1.92),(.70,.43,.24),'moss','Body',2)
  box('Crowned head',(0,-.02,2.25),(.56,.47,.54),'ancient_edge','Head',.09)
  for x in [-.17,.17]:box('Runic eyes',(x,-.265,2.27),(.13,.025,.065),'rune','Head',.01)
  box('Heart rune',(0,-.325,1.58),(.18,.03,.35),'rune','Body',.02)
  for side,suffix in [(-1,'L'),(1,'R')]:
   box('Boulder shoulder',(side*.74,0,1.79),(.52,.60,.56),'ancient','Arm_'+suffix,.10)
   box('Stone arm',(side*.83,-.03,1.30),(.40,.45,.70),'ancient_edge','Arm_'+suffix,.07)
   box('Granite fist',(side*.83,-.08,.88),(.52,.55,.40),'ancient','Arm_'+suffix,.07)
   box('Pillar leg',(side*.28,0,.57),(.39,.44,.68),'ancient','Leg_'+suffix,.07)
   box('Broad foot',(side*.28,-.12,.17),(.48,.65,.32),'ancient_edge','Leg_'+suffix,.07)
   for z in [1.45,1.72]:box('Arm seal',(side*.84,-.275,z),(.14,.035,.05),'rune','Arm_'+suffix,.01)
   for i in range(3):cone('Crown crystal',(side*(.12+i*.1),0,2.65+i*.07),.07,0,.4,'rune','Head',5)
  pivots={'Body':(0,0,1),'Head':(0,0,2),'Arm_L':(-.66,0,1.9),'Arm_R':(.66,0,1.9),'Leg_L':(-.28,0,.88),'Leg_R':(.28,0,.88)}
 else:
  cone('Floating mantle',(0,0,1.12),.67,.27,1.45,'storm','Body',10)
  for i in range(10):
   a=i*math.tau/10
   beam('Gold hem',(math.cos(a)*.65,math.sin(a)*.65,.41),(math.cos(a)*.30,math.sin(a)*.30,1.71),.023,'storm_gold','Body')
  ico('Breastplate',(0,0,1.78),(.42,.29,.36),'storm_gold','Body',2)
  ico('Faceless helm',(0,-.03,2.26),(.31,.27,.37),'storm','Head',2)
  box('Visor lightning',(0,-.30,2.28),(.34,.025,.085),'lightning','Head',.01)
  for side,suffix in [(-1,'L'),(1,'R')]:
   cone('Shoulder spike',(side*.50,0,1.98),.23,0,.50,'storm_gold','Arm_'+suffix,6)
   beam('Gauntlet arm',(side*.45,0,1.83),(side*.65,-.17,1.25),.12,'storm','Arm_'+suffix)
   ico('Arc hand',(side*.65,-.17,1.24),(.16,.16,.19),'lightning','Arm_'+suffix,2)
  beam('Storm staff',(.7,-.17,.45),(.7,-.17,2.70),.045,'storm_gold','Arm_R')
  ico('Staff prism',(.7,-.17,2.85),(.18,.18,.34),'lightning','Arm_R',1)
  for i in range(7):
   a=i*math.tau/7;ico('Orbit crystal',(math.cos(a)*.63,.18,2.40+math.sin(a)*.63),(.07,.07,.20),'lightning','Head',1)
  pivots={'Body':(0,0,1),'Head':(0,0,2),'Arm_L':(-.42,0,1.8),'Arm_R':(.42,0,1.8),'Leg_L':(-.18,0,.6),'Leg_R':(.18,0,.6)}
 rig_custom(name,pivots);export(name,animated=True)
 print('GUARDIAN EXPORTED',name)
