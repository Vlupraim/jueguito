"""Reference v04: continuous bald base, independent sackcloth, donor animation rig.
Blender 5.2 background authoring. Does not replace any game asset.
"""
import bpy, bmesh, math, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'art/characters/castaway_base_v02';OUT.mkdir(parents=True,exist_ok=True)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/characters/rig_reference/strongman_recovered_reference_v01.blend'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.name='CastawayRig'
rig.data.pose_position='REST';rig.animation_data.action=None
for t in rig.animation_data.nla_tracks:t.mute=True
for o in list(bpy.data.objects):
    if o!=rig:bpy.data.objects.remove(o,do_unlink=True)
heads={b.name:rig.matrix_world@b.head_local for b in rig.data.bones}
skinparts=[];details=[]
def clamp(t):return max(0,min(1,t))
def smooth(t):t=clamp(t);return t*t*(3-2*t)
def gauss(x,c,w):return math.exp(-((x-c)/w)**2)
def make(name,vs,fs,container):
    d=bpy.data.meshes.new(name);d.from_pydata(vs,[],fs);d.update()
    o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);container.append(o);return o
def rings(name,rs,n=32,container=skinparts):
    vs=[(x+rx*math.sin(j*math.tau/n),y-ry*math.cos(j*math.tau/n),z) for x,y,z,rx,ry in rs for j in range(n)]
    fs=[(k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j) for k in range(len(rs)-1) for j in range(n)]
    fs.extend([tuple(reversed(range(n))),tuple((len(rs)-1)*n+j for j in range(n))])
    return make(name,vs,fs,container)
def tube(name,centers,radii,n=16):
    d=(Vector(centers[-1])-Vector(centers[0])).normalized();a=d.cross(Vector((0,1,0))).normalized();b=d.cross(a)
    vs=[tuple(Vector(c)+r*(math.cos(j*math.tau/n)*a+math.sin(j*math.tau/n)*b)) for c,r in zip(centers,radii) for j in range(n)]
    fs=[(k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j) for k in range(len(centers)-1) for j in range(n)]
    fs.extend([tuple(reversed(range(n))),tuple((len(centers)-1)*n+j for j in range(n))])
    return make(name,vs,fs,skinparts)
def ellipsoid(name,c,s,n=20,rows=12):
    rs=[]
    for i in range(rows+1):
        a=math.pi*(i+.03)/(rows+.06);rs.append((c[0],c[1],c[2]+s[2]*math.cos(a),s[0]*math.sin(a),s[1]*math.sin(a)))
    return rings(name,rs,n)
def join(objects,name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();o=bpy.context.object;o.name=name;return o
def apply(o,kind,name,**kw):
    bpy.context.view_layer.objects.active=o;m=o.modifiers.new(name,kind)
    for k,v in kw.items():setattr(m,k,v)
    bpy.ops.object.modifier_apply(modifier=m.name)

# Head surface: cheek, orbital, nose and lip shapes belong to the same mesh.
profile=[(1.49,.030,.030,.020),(1.51,.049,.051,.006),(1.535,.066,.062,.005),(1.56,.079,.070,.010),(1.59,.087,.076,.014),(1.62,.091,.078,.014),(1.65,.091,.078,.015),(1.68,.091,.079,.018),(1.71,.086,.080,.024),(1.735,.069,.069,.025),(1.755,.035,.041,.024),(1.761,.005,.008,.024)]
def prof(z):
    for a,b in zip(profile,profile[1:]):
        if z<=b[0]:
            t=clamp((z-a[0])/(b[0]-a[0]));return [a[i]*(1-t)+b[i]*t for i in range(1,4)]
    return list(profile[-1][1:])
def front_y(x,z):
    rx,ry,cy=prof(z);q=min(.9999,abs(x)/rx)
    y=cy-ry*(1-q*q)**.30
    y-=.017*gauss(x,0,.012)*gauss(z,1.643,.035) # bridge
    y-=.034*gauss(x,0,.014)*gauss(z,1.614,.013) # tip
    y-=.011*(gauss(x,-.014,.008)+gauss(x,.014,.008))*gauss(z,1.610,.009)
    y-=.006*gauss(x,0,.027)*gauss(z,1.580,.011) # mouth volume
    y-=.006*gauss(x,0,.026)*gauss(z,1.549,.014) # chin
    y+=.008*(gauss(x,-.038,.024)+gauss(x,.038,.024))*gauss(z,1.646,.011)
    y-=.006*(gauss(x,-.037,.024)+gauss(x,.037,.024))*gauss(z,1.663,.009)
    y-=.004*(gauss(x,-.056,.023)+gauss(x,.056,.023))*gauss(z,1.617,.021)
    return y
vs=[];n=80;rows=74
for i in range(rows):
    z=profile[0][0]+(profile[-1][0]-profile[0][0])*i/(rows-1);rx,ry,cy=prof(z)
    for j in range(n):
        a=j*math.tau/n;x=rx*math.sin(a);c=math.cos(a)
        y=front_y(x,z) if c>=0 else cy+ry*(-c)**.65
        vs.append((x,y,z))
fs=[(i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j) for i in range(rows-1) for j in range(n)]
fs.extend([tuple(reversed(range(n))),tuple((rows-1)*n+j for j in range(n))])
make('HeadSculpt',vs,fs,skinparts)
rings('Neck',[(0,.016,1.375,.063,.055),(0,.015,1.425,.052,.051),(0,.017,1.474,.041,.045),(0,.019,1.52,.042,.045)])
for s in [-1,1]:ellipsoid('Ear',(s*.091,.011,1.630),(.018,.014,.031),20,14)
rings('Torso',[(.003,-.022,.82,.104,.089),(.003,-.022,.88,.148,.105),(.003,-.015,.96,.154,.103),(.003,-.006,1.04,.136,.093),(.002,.001,1.12,.135,.096),(.002,.008,1.20,.157,.107),(.001,.014,1.28,.179,.110),(0,.017,1.345,.198,.099),(0,.017,1.38,.170,.078),(0,.016,1.408,.083,.056)])
for side,s in [('Left',1),('Right',-1)]:
    sh,el,wr=[heads[side+b] for b in ['Arm','ForeArm','Hand']]
    ellipsoid('ShoulderBridge',(s*.192,.018,1.359),(.078,.052,.049),24,16)
    ellipsoid('Deltoid',sh+Vector((-s*.012,0,-.032)),(.054,.052,.063),24,16)
    tube('Arm',[sh.lerp(el,.10),sh.lerp(el,.30),sh.lerp(el,.62),el,el.lerp(wr,.18),el.lerp(wr,.43),el.lerp(wr,.72),wr,wr+Vector((s*.008,-.005,-.025))],[.025,.055,.052,.043,.049,.049,.036,.025,.024],24)
    palm=wr+Vector((s*.012,-.004,-.037))
    ellipsoid('Palm',palm,(.037,.019,.052),24,16)
    for j,L in enumerate([.049,.056,.051,.039]):
        p=palm+Vector((s*(j-1.5)*.018,-.001,-.030));q=p+Vector((s*(j-1.5)*.003,-.005,-L*.50));r=p+Vector((s*(j-1.5)*.004,-.006,-L))
        tube('Finger',[p,q,r],[.010,.009,.007],12)
        ellipsoid('Fingertip',r,(.007,.007,.007),12,8)
    p=palm+Vector((-s*.025,-.002,.010));q=p+Vector((-s*.027,-.009,-.017));r=q+Vector((-s*.010,-.008,-.023))
    tube('Thumb',[p,q,r],[.014,.011,.008],12);ellipsoid('Thumbtip',r,(.008,.008,.008),12,8)
    hip,knee,ankle=[heads[side+b] for b in ['UpLeg','Leg','Foot']]
    tube('Leg',[hip+Vector((0,0,.050)),hip,hip.lerp(knee,.30),hip.lerp(knee,.64),hip.lerp(knee,.86),knee,knee.lerp(ankle,.15),knee.lerp(ankle,.34),knee.lerp(ankle,.58),knee.lerp(ankle,.82),ankle],[.092,.099,.094,.075,.057,.053,.058,.062,.050,.032,.029],24)
    ellipsoid('Heel',ankle+Vector((0,.010,-.041)),(.039,.050,.048),24,16)
    ellipsoid('Instep',ankle+Vector((0,-.050,-.049)),(.045,.088,.040),24,16)
    ellipsoid('Forefoot',ankle+Vector((s*.008,-.098,-.070)),(.052,.052,.025),24,14)
    for j in range(5):
        x=ankle.x+s*((j-2)*.020+.009);y=ankle.y-.139+j*.006;z=ankle.z-.075
        ellipsoid('Toe',(x,y,z),(.012-j*.0009,.029-j*.003,.018-j*.0015),16,10)

body=join(skinparts,'Body_Base')
bm=bmesh.new();bm.from_mesh(body.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(body.data);bm.free()
# Voxel union removes intersections and gaps; decimation follows smoothing, before skinning.
apply(body,'REMESH','ContinuousSurface',mode='VOXEL',voxel_size=.0032,use_smooth_shade=True)
apply(body,'SMOOTH','GentleRelax',factor=.55,iterations=3)
apply(body,'DECIMATE','GameSurface',ratio=.045)

def spine(z):
    c=[('Hips',.95),('Spine02',1.0875),('Spine01',1.224),('Spine',1.36),('neck',1.462),('Head',1.515)]
    if z<=c[0][1]:return {'Hips':1}
    for (a,za),(b,zb) in zip(c,c[1:]):
        if z<=zb:
            t=smooth((z-za)/(zb-za));return {a:1-t,b:t}
    return {'Head':1}
def weights(p):
    x,y,z=p;side='Left' if x>0 else 'Right'
    if z>1.49:return {'Head':1}
    arm_boundary=.15+max(0,1.36-z)*.32
    if abs(x)>arm_boundary:
        sh,el,wr=[heads[side+b] for b in ['Arm','ForeArm','Hand']]
        if z>el.z+.065:w={side+'Arm':1}
        elif z>el.z-.065:
            t=smooth((el.z+.065-z)/.13);w={side+'Arm':1-t,side+'ForeArm':t}
        elif z>wr.z+.03:w={side+'ForeArm':1}
        elif z>wr.z-.018:
            t=smooth((wr.z+.03-z)/.048);w={side+'ForeArm':1-t,side+'Hand':t}
        else:w={side+'Hand':1}
        shoulder_mix=smooth((abs(x)-arm_boundary)/.085)
        r={k:v*(1-shoulder_mix) for k,v in spine(z).items()}
        for k,v in w.items():r[k]=r.get(k,0)+v*shoulder_mix
        return r
    if z<.94:
        knee=heads[side+'Leg'].z;ankle=heads[side+'Foot'].z
        if z>knee+.065:w={side+'UpLeg':1}
        elif z>knee-.065:
            t=smooth((knee+.065-z)/.13);w={side+'UpLeg':1-t,side+'Leg':t}
        elif z>ankle+.04:w={side+'Leg':1}
        else:
            t=smooth((ankle+.04-z)/.07);w={side+'Leg':1-t,side+'Foot':t}
        t=smooth((.94-z)/.13)
        return {'Hips':1-t,**{k:v*t for k,v in w.items()}}
    return spine(z)
def skinned(o,fn):
    # Preserve donor .01 transform and original bone rest matrices.
    groups={}
    for v in o.data.vertices:
        for name,w in fn(v.co).items():
            if w<1e-6:continue
            if name not in groups:groups[name]=o.vertex_groups.new(name=name)
            groups[name].add([v.index],w,'REPLACE')
        v.co*=100
    o.parent=rig;o.matrix_world=rig.matrix_world.copy()
    m=o.modifiers.new('Skin','ARMATURE');m.object=rig
    for p in o.data.polygons:p.use_smooth=True
def paintmaterial(name):
    m=bpy.data.materials.new(name);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Roughness'].default_value=.91;p.inputs['Specular IOR Level'].default_value=.12
    vc=m.node_tree.nodes.new('ShaderNodeVertexColor');vc.layer_name='Paint';m.node_tree.links.new(vc.outputs['Color'],p.inputs['Base Color']);return m
skinmat=paintmaterial('Skin_Painted');clothmat=paintmaterial('Sackcloth_Painted')
def paint(o,fn,material):
    o.data.materials.clear();o.data.materials.append(material)
    c=o.data.color_attributes.new(name='Paint',type='FLOAT_COLOR',domain='CORNER')
    for p in o.data.polygons:
        for li in p.loop_indices:c.data[li].color=(*fn(o.data.vertices[o.data.loops[li].vertex_index].co),1)
def skincolor(p):
    x,y,z=p;v=.018*math.sin(x*41+z*27)*math.sin(z*55-y*29)
    col=Vector((.43,.252,.157))*(1+v)
    if z>1.5 and y<.015:
        blush=(gauss(x,-.055,.025)+gauss(x,.055,.025))*gauss(z,1.61,.027)*.12
        col=col.lerp(Vector((.42,.205,.14)),blush)
        lip=gauss(x,0,.026)*gauss(z,1.580,.006)*.47
        col=col.lerp(Vector((.27,.105,.068)),lip)
        orbit=(gauss(x,-.038,.023)+gauss(x,.038,.023))*gauss(z,1.640,.008)*.12
        col*=1-orbit
    return tuple(col)
paint(body,skincolor,skinmat);skinned(body,weights);body['module']='Body'

# Thin facial features lie on the face surface instead of protruding eyeball primitives.
def flatmat(name,c):
    m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);m.use_nodes=True
    b=m.node_tree.nodes.get('Principled BSDF');b.inputs['Base Color'].default_value=(*c,1);b.inputs['Roughness'].default_value=.9;b.inputs['Specular IOR Level'].default_value=.1;return m
ivory=flatmat('Eye_Ivory',(.46,.40,.31));iris=flatmat('Iris_Brown',(.048,.026,.010));pupil=flatmat('Pupil',(.007,.005,.003));browmat=flatmat('Eyebrow',(.035,.018,.009));crease=flatmat('SoftCrease',(.17,.075,.039))
def feature(name,xzs,fs,mat,offset=.0010):
    vs=[(x,front_y(x,z)-offset,z) for x,z in xzs]
    o=make(name,vs,fs,details);o.data.materials.append(mat);skinned(o,lambda p:{'Head':1});o['module']='Face';return o
for s in [-1,1]:
    cx=s*.037;cz=1.646;n=32
    # Almond contour, with slight outer-corner lift.
    pts=[(cx,cz)]+[(cx+.020*math.cos(a),cz+.0062*math.sin(a)*abs(math.sin(a))**.25+s*.001*math.cos(a)) for a in [j*math.tau/n for j in range(n)]]
    feature('Eye_'+str(s),pts,[(0,j+1,(j+1)%n+1) for j in range(n)],ivory,.0017)
    for r,mat,off in [(.0058,iris,.0023),(.0028,pupil,.0027)]:
        pts=[(cx,cz)]+[(cx+r*math.cos(j*math.tau/24),cz+r*math.sin(j*math.tau/24)) for j in range(24)]
        feature('Iris',pts,[(0,j+1,(j+1)%24+1) for j in range(24)],mat,off)
    pts=[]
    for j in range(17):
        a=j*math.pi/16;x=cx+.020*math.cos(a);z=cz+.0062*math.sin(a)**1.25+s*.001*math.cos(a)
        pts.extend([(x,z),(x,z+.0009)])
    feature('UpperLash',pts,[(2*j,2*j+1,2*j+3,2*j+2) for j in range(16)],crease,.0025)
    pts=[]
    for j in range(13):
        t=j/12;x=s*(.015+.048*t);z=1.668+.004*math.sin(t*math.pi)-.004*t
        pts.extend([(x,z),(x,z+.0038*math.sin(.25+t*2.5))])
    feature('Brow',pts,[(2*j,2*j+1,2*j+3,2*j+2) for j in range(12)],browmat,.0018)
    # small nostril accent flush to the nose, not a separate lump.
    pts=[(s*.011+.004*math.cos(j*math.tau/16),1.607+.0015*math.sin(j*math.tau/16)) for j in range(16)]
    feature('Nostril',pts,[tuple(range(16))],crease,.0018)
pts=[]
for j in range(25):
    x=-.025+.05*j/24;z=1.579+.0015*(abs(x)/.025)**1.5
    pts.extend([(x,z),(x,z+.0008*math.sin(j*math.pi/24))])
feature('MouthLine',pts,[(2*j,2*j+1,2*j+3,2*j+2) for j in range(24)],crease,.0015)

# Single sackcloth shift, open hem and neckline, real arm openings, no finished equipment.
garment=[];n=64
rs=[(.665,.247,.191),(.70,.245,.190),(.78,.239,.189),(.87,.222,.187),(.97,.198,.150),(1.07,.183,.123),(1.17,.184,.124),(1.25,.197,.128),(1.29,.201,.125),(1.33,.207,.121),(1.365,.220,.115),(1.395,.224,.100),(1.415,.145,.080),(1.425,.051,.053)]
vs=[]
for k,(z,rx,ry) in enumerate(rs):
    for j in range(n):
        a=j*math.tau/n;fold=(.0035*math.sin(a*9+.3)+.002*math.sin(a*15+z*6))*smooth((1.44-z)/.35)
        zz=z+(.004*math.sin(a*7)+.003*math.sin(a*13) if k==0 else 0)
        vs.append(((rx+fold)*math.sin(a),.012-(ry+fold)*math.cos(a),zz))
fs=[]
for k in range(len(rs)-1):
    for j in range(n):
        ids=(k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j);c=sum((Vector(vs[i]) for i in ids),Vector())/4
        if 1.295<c.z<1.375 and abs(c.x)>.18:continue
        fs.append(ids)
cloth=make('Base_Covering',vs,fs,garment)
apply(cloth,'SUBSURF','BroadFolds',levels=1,render_levels=1)
apply(cloth,'SOLIDIFY','ClothThickness',thickness=.0015,offset=0)
apply(cloth,'DECIMATE','ClothBudget',ratio=.24)
def clothcolor(p):
    x,y,z=p;a=math.atan2(x/.21,-(y-.012)/.14)
    v=.045*math.sin(a*9+.3)+.020*math.sin(z*25+x*11)+.012*math.sin(x*110+z*89)*math.sin(z*137)
    dirt=.10*(1-smooth((z-.665)/.16))
    return tuple(Vector((.335,.302,.235))*(1+v-dirt))
paint(cloth,clothcolor,clothmat)
def clothweights(p):
    if p.z<.96:
        side='LeftUpLeg' if p.x>0 else 'RightUpLeg';w=.70*smooth((.96-p.z)/.30)*smooth(abs(p.x)/.15)
        return {'Hips':1-w,side:w}
    return spine(p.z)
skinned(cloth,clothweights);cloth['module']='BaseCovering'
cloth['equipment_rule']='Hide or replace appropriate garment/body regions when equipping clothing. Not implemented in gameplay.'

for name,bone,world in [('Socket_Hair','Head',Vector((0,.022,1.70))),('Socket_Weapon_R','RightHand',heads['RightHand']),('Socket_Offhand_L','LeftHand',heads['LeftHand'])]:
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.parent=rig;o.parent_type='BONE';o.parent_bone=bone;o.empty_display_size=.02
    bpy.context.view_layer.update();o.matrix_world.translation=world;o['bone_contract']=bone
# Facial paint comes from the approved front portrait, projected and baked into
# the new surface. Source image stays unchanged; this is mesh texture authoring.
for o in details:bpy.data.objects.remove(o,do_unlink=True)
details=[]
src=bpy.data.images.load(str(ROOT/'jueguito/docs/design/concepts/art_direction/castaway_male_base_reference_v04.png'),check_existing=True);src.pack()
uv=body.data.uv_layers.new(name='FaceProjection')
blend=body.data.color_attributes.new(name='FaceBlend',type='FLOAT_COLOR',domain='CORNER')
landmarks=[(1.49,852),(1.515,824),(1.549,800),(1.579,766),(1.614,728),(1.646,677),(1.668,657),(1.71,595),(1.761,540)]
def image_y(z):
    for (a,pa),(b,pb) in zip(landmarks,landmarks[1:]):
        if z<=b:return pa+(pb-pa)*clamp((z-a)/(b-a))
    return 540
for poly in body.data.polygons:
    for li in poly.loop_indices:
        p=body.data.vertices[body.data.loops[li].vertex_index].co/100
        face_scale=930+205*smooth((p.z-1.55)/.09)
        uv.data[li].uv=((1310+p.x*face_scale)/1536,1-image_y(p.z)/1024)
        rx,ry,cy=prof(p.z)
        w=smooth((cy-p.y)/.035)*smooth((p.z-1.50)/.028)
        w*=1-smooth((abs(p.x)-.062)/.022)
        w*=1-smooth((p.z-1.705)/.035)
        w*=1-smooth((abs(p.x)/max(rx,.01)-.65)/.30)
        blend.data[li].color=(w,w,w,1)
nodes=skinmat.node_tree.nodes;links=skinmat.node_tree.links
bs=nodes.get('Principled BSDF');vc=next(n for n in nodes if n.type=='VERTEX_COLOR')
tx=nodes.new('ShaderNodeTexImage');tx.image=src
uvn=nodes.new('ShaderNodeUVMap');uvn.uv_map='FaceProjection';links.new(uvn.outputs[0],tx.inputs[0])
mask=nodes.new('ShaderNodeVertexColor');mask.layer_name='FaceBlend'
mix=nodes.new('ShaderNodeMixRGB');links.new(mask.outputs['Color'],mix.inputs[0]);links.new(vc.outputs['Color'],mix.inputs[1]);links.new(tx.outputs['Color'],mix.inputs[2]);links.new(mix.outputs[0],bs.inputs['Base Color'])
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);bpy.context.view_layer.objects.active=body
atlas=body.data.uv_layers.new(name='UVMap');body.data.uv_layers.active=atlas;atlas.active_render=True
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.008);bpy.ops.object.mode_set(mode='OBJECT')
baked=bpy.data.images.new('Body_BaseColor',width=2048,height=2048,alpha=False)
target=nodes.new('ShaderNodeTexImage');target.image=baked;nodes.active=target
bpy.context.scene.render.engine='CYCLES';bpy.context.scene.cycles.samples=1
bpy.context.scene.render.bake.use_pass_direct=False;bpy.context.scene.render.bake.use_pass_indirect=False;bpy.context.scene.render.bake.use_pass_color=True;bpy.context.scene.render.bake.margin=12
bpy.ops.object.bake(type='DIFFUSE')
baked.filepath_raw=str(OUT/'body_basecolor.png');baked.file_format='PNG';baked.save();baked.pack()
links.new(target.outputs['Color'],bs.inputs['Base Color'])
for node in list(nodes):
    if node not in [target,bs,nodes.get('Material Output')]:nodes.remove(node)
body['paint_source']='Approved v04 frontal portrait projected onto new geometry and baked; body color vertex-authored.'
# Fabric pigments come from a clean interior area of the reference's front shift.
nodes=clothmat.node_tree.nodes;links=clothmat.node_tree.links;bs=nodes.get('Principled BSDF')
projection=cloth.data.uv_layers.new(name='FabricProjection')
for li,loop in enumerate(cloth.data.loops):
    p=cloth.data.vertices[loop.vertex_index].co/100
    projection.data[li].uv=((215+p.x*220)/1536,1-(270+(1.425-p.z)*390)/1024)
tx=nodes.new('ShaderNodeTexImage');tx.image=src;uvn=nodes.new('ShaderNodeUVMap');uvn.uv_map='FabricProjection';links.new(uvn.outputs[0],tx.inputs[0]);links.new(tx.outputs['Color'],bs.inputs['Base Color'])
bpy.ops.object.select_all(action='DESELECT');cloth.select_set(True);bpy.context.view_layer.objects.active=cloth
atlas=cloth.data.uv_layers.new(name='UVMap');cloth.data.uv_layers.active=atlas;atlas.active_render=True
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.008);bpy.ops.object.mode_set(mode='OBJECT')
baked=bpy.data.images.new('Sackcloth_BaseColor',width=1024,height=1024,alpha=False);target=nodes.new('ShaderNodeTexImage');target.image=baked;nodes.active=target
bpy.ops.object.bake(type='DIFFUSE');baked.filepath_raw=str(OUT/'sackcloth_basecolor.png');baked.file_format='PNG';baked.save();baked.pack();links.new(target.outputs['Color'],bs.inputs['Base Color'])
for node in list(nodes):
    if node not in [target,bs,nodes.get('Material Output')]:nodes.remove(node)
# The complete body remains editable. This reversible modifier is the initial
# clothing coverage rule, and exports only the visible body for this outfit.
covered=body.vertex_groups.new(name='Coverage_BaseShift')
for v in body.data.vertices:
    p=v.co/100
    if (.685<p.z<1.20 and abs(p.x)<.245) or (1.20<=p.z<1.405 and abs(p.x)<.10):covered.add([v.index],1,'REPLACE')
maskmod=body.modifiers.new('Hide_under_base_covering','MASK');maskmod.vertex_group=covered.name;maskmod.invert_vertex_group=True
maskmod.use_smooth=True;maskmod.threshold=.5
body['coverage_rule']='Disable Hide_under_base_covering to edit full anatomy; adapt coverage for each equipped outfit.'
modules=[body,cloth]
rig['base_contract']='Bald base; hair will be a separate Head-skinned module.'

# Neutral material review, without miniature-style depth of field or heavy specular.
scene=bpy.context.scene
if not scene.world:scene.world=bpy.data.worlds.new('World')
scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.40,.40,.40,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.7
def point(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
for name,loc,energy,size in [('Key',(-3,-4,5),320,5),('Fill',(3,-2,3),180,4)]:
    d=bpy.data.lights.new(name,'AREA');d.energy=energy;d.shape='DISK';d.size=size;o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);o.location=loc;point(o,(0,0,1))
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.015));ground=bpy.context.object;ground.name='Studio_Ground';ground.data.materials.append(flatmat('Background',(.47,.45,.40)))
d=bpy.data.cameras.new('ReviewCamera');cam=bpy.data.objects.new('ReviewCamera',d);bpy.context.collection.objects.link(cam);d.type='ORTHO';d.ortho_scale=1.98;cam.location=(1.2,-5,2);point(cam,(0,0,.91));scene.camera=cam
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.resolution_x=950;scene.render.resolution_y=1150;scene.render.resolution_percentage=100;scene.view_settings.view_transform='AgX'
scene.render.image_settings.file_format='PNG'
for a in bpy.context.screen.areas:
    if a.type=='VIEW_3D':
        a.spaces.active.region_3d.view_distance=2.5;a.spaces.active.region_3d.view_location=(0,0,.9);a.spaces.active.region_3d.view_rotation=cam.rotation_euler.to_quaternion();a.spaces.active.shading.type='MATERIAL';a.spaces.active.overlay.show_extras=False
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);bpy.context.view_layer.objects.active=body
scene['reference']='castaway_male_base_reference_v04.png';scene['status']='Reference-driven second prototype. Pending art approval; no gameplay replacement.'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'castaway_base_v02.blend'))
scene.render.filepath=str(OUT/'review_full.png');bpy.ops.render.render(write_still=True)
cam.location=(.35,-4,1.68);point(cam,(0,-.01,1.63));cam.data.ortho_scale=.38;scene.render.resolution_x=900;scene.render.resolution_y=900
scene.render.filepath=str(OUT/'review_face.png');bpy.ops.render.render(write_still=True)
report={'bones':len(rig.data.bones),'actions':len(bpy.data.actions),'meshes':{o.name:{'vertices':len(o.data.vertices),'triangles':sum(len(p.vertices)-2 for p in o.data.polygons)} for o in modules}}
(OUT/'build_report.json').write_text(json.dumps(report,indent=2),encoding='utf8');print('BUILD_OK')
