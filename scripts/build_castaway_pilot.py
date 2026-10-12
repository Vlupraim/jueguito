"""Build a new low-poly castaway pilot around the recovered donor rig.
Run in Blender background. Keeps gameplay files and donor blend unchanged.
"""
import bpy, math, json, random
from pathlib import Path
from mathutils import Vector, Quaternion

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'art/characters/castaway_male_v01'
OUT.mkdir(parents=True,exist_ok=True)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/characters/rig_reference/strongman_recovered_reference_v01.blend'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
rig.name='CastawayRig'
rig.data.pose_position='REST'
for o in list(bpy.data.objects):
    if o!=rig: bpy.data.objects.remove(o,do_unlink=True)
for t in rig.animation_data.nla_tracks: t.mute=True
rig.animation_data.action=None
rig.show_in_front=False
rig.hide_render=True
heads={b.name:rig.matrix_world@b.head_local for b in rig.data.bones}
parts=[]

def mat(name,color):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF'); bs.inputs['Roughness'].default_value=.83
    v=m.node_tree.nodes.new('ShaderNodeVertexColor'); v.layer_name='Paint'
    m.node_tree.links.new(v.outputs['Color'],bs.inputs['Base Color'])
    return m,color
skin=mat('Skin_warm_matte',(.55,.32,.20))
cloth=mat('Linen_weathered',(.48,.405,.285))
edge=mat('Linen_fold_edges',(.59,.50,.35))
pants=mat('Trousers_olive_charcoal',(.145,.165,.12))
leather=mat('Leather_worn',(.19,.103,.054))
hairmat=mat('Hair_chestnut',(.095,.042,.023))
white=mat('Eye_ivory',(.62,.61,.48))
iris=mat('Iris_hazel',(.15,.22,.16))
dark=mat('Pupil_and_lash',(.025,.015,.010))
lip=mat('Lips_muted',(.35,.15,.10))
brass=mat('Buckle_aged',(.38,.28,.12))

def spineweights(z):
    chain=[('Hips',.94),('Spine02',1.0875),('Spine01',1.2238),('Spine',1.36),('neck',1.467)]
    if z<=chain[0][1]: return {'Hips':1}
    for (a,za),(b,zb) in zip(chain,chain[1:]):
        if z<=zb:
            t=(z-za)/(zb-za); return {a:1-t,b:t}
    return {'neck':1}

def mesh(name,verts,faces,material,weights,module):
    data=bpy.data.meshes.new(name); data.from_pydata([tuple(Vector(v)*100) for v in verts],[],faces); data.update()
    o=bpy.data.objects.new(name,data); bpy.context.collection.objects.link(o)
    o.matrix_world=rig.matrix_world.copy(); o.data.materials.append(material[0])
    groups={}
    for i,p in enumerate(verts):
        w=weights(Vector(p)) if callable(weights) else weights
        for bone,value in w.items():
            if value<=0:continue
            if bone not in groups:groups[bone]=o.vertex_groups.new(name=bone)
            groups[bone].add([i],value,'REPLACE')
    mod=o.modifiers.new('Skin','ARMATURE');mod.object=rig
    o.parent=rig; o.matrix_world=rig.matrix_world.copy()
    colors=data.color_attributes.new(name='Paint',type='BYTE_COLOR',domain='CORNER')
    for poly in data.polygons:
        for li in poly.loop_indices:
            p=Vector(verts[data.loops[li].vertex_index])
            f=1+.045*math.sin(p.x*39+p.z*18)+.025*math.sin(p.z*72+p.y*21)
            colors.data[li].color=tuple(min(1,c*f) for c in material[1])+(1,)
    o['module']=module;parts.append(o);return o

def rings(name,rs,n,material,weights,module):
    # ring entries: center x,y,z, radius x,y
    vs=[]
    for cx,cy,z,rx,ry in rs:
        for j in range(n):
            a=2*math.pi*j/n
            vs.append((cx+rx*math.sin(a),cy-ry*math.cos(a),z))
    fs=[]
    for k in range(len(rs)-1):
        for j in range(n):fs.append((k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j))
    fs.extend([tuple(reversed(range(n))),tuple((len(rs)-1)*n+j for j in range(n))])
    return mesh(name,vs,fs,material,weights,module)

def tube(name,centers,radii,material,bones,module,n=10):
    vs=[]; direction=(Vector(centers[-1])-Vector(centers[0])).normalized()
    cross=direction.cross(Vector((0,1,0))).normalized(); other=direction.cross(cross).normalized()
    for c,r in zip(centers,radii):
        for j in range(n):
            a=j*math.tau/n;vs.append(Vector(c)+r*(math.cos(a)*cross+math.sin(a)*other))
    fs=[]
    for k in range(len(centers)-1):
        for j in range(n):fs.append((k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j))
    fs.extend([tuple(reversed(range(n))),tuple((len(centers)-1)*n+j for j in range(n))])
    return mesh(name,vs,fs,material,bones,module)

def ellipsoid(name,c,s,material,bone,module,seg=12,rows=7):
    vs=[]
    for i in range(rows+1):
        lat=math.pi*(i+.02)/(rows+.04)
        for j in range(seg):
            a=math.tau*j/seg
            vs.append((c[0]+s[0]*math.sin(lat)*math.cos(a),c[1]+s[1]*math.sin(lat)*math.sin(a),c[2]+s[2]*math.cos(lat)))
    fs=[]
    for i in range(rows):
        for j in range(seg):fs.append((i*seg+j,i*seg+(j+1)%seg,(i+1)*seg+(j+1)%seg,(i+1)*seg+j))
    fs.extend([tuple(reversed(range(seg))),tuple(rows*seg+j for j in range(seg))])
    return mesh(name,vs,fs,material,{bone:1},module)

# Body visible at neck and arms: independent from outfit.
rings('Neck',[(0,.012,1.39,.059,.055),(0,.012,1.48,.047,.045),(0,.012,1.535,.051,.052)],12,skin,lambda p:spineweights(p.z),'Body')

# An authored head silhouette: narrow chin, cheek planes, rounded cranium.
rings('Head',[(0,.001,1.505,.036,.042),(0,-.002,1.527,.061,.061),(0,.002,1.565,.083,.079),(0,.005,1.607,.096,.086),(0,.008,1.65,.098,.082),(0,.012,1.691,.09,.081),(0,.018,1.729,.071,.067),(0,.019,1.747,.035,.037)],16,skin,{'Head':1},'Body')
for side in [-1,1]:
    ellipsoid('Ear', (side*.101,.008,1.613),(.020,.018,.039),skin,'Head','Body',10,5)
    ellipsoid('Ear_inner',(side*.111,-.009,1.613),(.010,.004,.022),lip,'Head','Body',8,4)
    # Eyes small enough to avoid toy-like eyeballs; front faces toward -Y.
    ellipsoid('Eye_socket',(side*.040,-.073,1.648),(.027,.010,.012),skin,'Head','Body',12,5)
    ellipsoid('Eye_white',(side*.040,-.081,1.648),(.024,.008,.009),white,'Head','Body',12,5)
    ellipsoid('Iris',(side*.039,-.0885,1.648),(.008,.0028,.008),iris,'Head','Body',12,5)
    ellipsoid('Pupil',(side*.039,-.0908,1.648),(.0038,.001,.005),dark,'Head','Body',10,4)
    mesh('Brow',[(side*.014,-.087,1.674),(side*.043,-.084,1.679),(side*.067,-.074,1.671),(side*.065,-.076,1.663),(side*.040,-.087,1.669),(side*.014,-.089,1.666)],[(0,1,2,3,4,5)],hairmat,{'Head':1},'Body')
    # upper eyelid accent
    tube('Upper_lid',[(side*.019,-.088,1.651),(side*.040,-.090,1.657),(side*.062,-.082,1.65)],[.0022]*3,skin,{'Head':1},'Body',6)
mesh('Nose', [(-.012,-.078,1.669),(.012,-.078,1.669),(-.014,-.098,1.611),(.014,-.098,1.611),(0,-.123,1.621),(-.020,-.085,1.609),(.020,-.085,1.609)],[(0,1,4),(1,3,4),(0,4,2),(2,4,3),(5,2,0),(1,3,6),(5,6,3,2)],skin,{'Head':1},'Body')
mesh('Mouth', [(-.032,-.077,1.579),(-.009,-.085,1.582),(0,-.086,1.579),(.009,-.085,1.582),(.032,-.077,1.579),(.016,-.083,1.574),(-.016,-.083,1.574)],[(0,1,2,3,4,5,6)],lip,{'Head':1},'Body')
tube('Mouth_line',[(-.025,-.082,1.578),(0,-.087,1.577),(.025,-.082,1.578)],[.0015]*3,dark,{'Head':1},'Body',6)

# Practical one-piece tunic with a broad belt and separately skinned sleeves.
def tunicweights(p):
    if p.z<.94:
        side='LeftUpLeg' if p.x>0 else 'RightUpLeg'
        w=min(.72,(.94-p.z)*2.8)*min(1,abs(p.x)/.08)
        return {'Hips':1-w,side:w}
    return spineweights(p.z)
rings('Tunic',[(0,.005,.72,.235,.14),(0,.005,.83,.218,.137),(0,.005,.965,.18,.118),(0,.005,1.075,.158,.105),(0,.008,1.17,.176,.115),(0,.013,1.30,.205,.125),(0,.015,1.375,.228,.114),(0,.012,1.415,.19,.094),(0,.012,1.445,.060,.056)],16,cloth,tunicweights,'Tunic')
rings('Hem_binding',[(0,.005,.716,.237,.142),(0,.005,.741,.234,.143)],16,edge,tunicweights,'Tunic')
rings('Neck_binding',[(0,.012,1.426,.071,.067),(0,.012,1.450,.060,.057)],12,edge,lambda p:spineweights(p.z),'Tunic')
rings('Belt',[(0,.005,1.027,.164,.112),(0,.005,1.076,.162,.111)],16,leather,lambda p:spineweights(p.z),'Tunic')
mesh('Buckle',[(-.030,-.110,1.033),(.030,-.110,1.033),(.030,-.110,1.07),(-.030,-.110,1.07)],[(0,1,2,3)],brass,{'Spine02':1},'Tunic')
mesh('Belt_tail',[(.025,-.112,1.05),(.05,-.112,1.05),(.055,-.131,.935),(.031,-.131,.926)],[(0,1,2,3)],leather,{'Hips':1},'Tunic')
mesh('Chest_lacing',[(-.012,-.106,1.427),(.012,-.106,1.427),(.011,-.119,1.344),(-.011,-.119,1.344)],[(0,1,2,3)],leather,{'Spine':1},'Tunic')

for side,sgn in [('Left',1),('Right',-1)]:
    shoulder=heads[side+'Arm']; elbow=heads[side+'ForeArm']; wrist=heads[side+'Hand']
    upper=side+'Arm'; fore=side+'ForeArm'; hand=side+'Hand'
    sleeve_end=elbow.lerp(wrist,.17)
    def sleeveweights(p,upper=upper,fore=fore,elbow=elbow):
        w=max(0,min(1,(elbow.z+.035-p.z)/.085))
        return {upper:1-w,fore:w}
    tube('Sleeve_'+side,[Vector((sgn*.165,.015,1.37)),shoulder.lerp(elbow,.22),shoulder.lerp(elbow,.6),elbow,sleeve_end],[.068,.082,.081,.073,.074],cloth,sleeveweights,'Tunic',12)
    tube('Cuff_'+side,[elbow.lerp(wrist,.12),elbow.lerp(wrist,.20)],[.078,.077],edge,{fore:1},'Tunic',12)
    tube('Forearm_'+side,[elbow.lerp(wrist,.1),elbow.lerp(wrist,.56),wrist],[.059,.049,.031],skin,{fore:1},'Body',12)
    # A stable, lightly curled grasp; donor has no independently animated finger bones.
    palm=wrist+Vector((sgn*.027,-.014,-.040))
    ellipsoid('Palm_'+side,palm,(.037,.033,.061),skin,hand,'Body',12,7)
    for j in range(4):
        start=palm+Vector(((j-1.5)*.016,-.017,-.036))
        mid=start+Vector((sgn*.012,-.014,-.027))
        end=mid+Vector((-sgn*.006,.020,-.014))
        tube('Finger_'+side,[start,mid,end],[.011,.010,.008],skin,{hand:1},'Body',7)
    tube('Thumb_'+side,[palm+Vector((-sgn*.028,-.008,.017)),palm+Vector((-sgn*.042,-.032,-.002)),palm+Vector((-sgn*.021,-.043,-.021))],[.015,.013,.010],skin,{hand:1},'Body',8)
    hip=heads[side+'UpLeg'];knee=heads[side+'Leg']; ankle=heads[side+'Foot']
    def legweights(p,side=side,knee=knee):
        w=max(0,min(1,(knee.z+.055-p.z)/.11))
        return {side+'UpLeg':1-w,side+'Leg':w}
    tube('Trousers_'+side,[hip.lerp(knee,.31),hip.lerp(knee,.55),knee+Vector((0,0,.045)),knee,knee-Vector((0,0,.045)),knee.lerp(ankle,.5),ankle],[.078,.077,.073,.071,.069,.060,.048],pants,legweights,'Trousers',12)
    tube('Boot_shaft_'+side,[ankle.lerp(knee,.48),ankle.lerp(knee,.23),ankle],[.077,.071,.065],leather,{side+'Leg':1},'Boots',10)
    footcenter=ankle+Vector((0,-.055,-.047))
    ellipsoid('Boot_foot_'+side,footcenter,(.073,.128,.062),leather,side+'Foot','Boots',12,6)
    ellipsoid('Boot_sole_'+side,footcenter+Vector((0,-.006,-.035)),(.076,.133,.018),dark,side+'Foot','Boots',12,4)

# Modular close-fitting hair cap and large, swept sculptural tufts.
rings('Hair_cap',[(0,.022,1.66,.101,.082),(0,.022,1.70,.100,.088),(0,.025,1.743,.082,.075),(0,.026,1.766,.039,.041)],16,hairmat,{'Head':1},'Hair_Default')
for i,(x,z) in enumerate([(-.073,1.719),(-.043,1.75),(-.009,1.768),(.025,1.761),(.057,1.747)]):
    mesh('Hair_lock',[(x-.025,-.047,z),(x+.025,-.042,z+.007),(x+.024,.025,z+.012),(x-.022,.025,z),(x-.025,-.095,z-.058),(x+.012,-.092,z-.045)],[(0,1,2,3),(0,4,5,1),(1,5,2),(3,2,5,4),(0,3,4)],hairmat,{'Head':1},'Hair_Default')

# Join geometry by equipment module. Preserve all materials and vertex groups.
modules={}
for name in ['Body','Tunic','Trousers','Boots','Hair_Default']:
    bpy.ops.object.select_all(action='DESELECT')
    selected=[o for o in bpy.data.objects if o.type=='MESH' and o.get('module')==name]
    for o in selected:o.select_set(True)
    bpy.context.view_layer.objects.active=selected[0];bpy.ops.object.join()
    o=bpy.context.object;o.name=name;modules[name]=o
    # triangles are explicit and stable for interchange
    tri=o.modifiers.new('Triangulate','TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=tri.name)

# A replaceable wig has its own centered origin; keep all surface positions unchanged.
wig=modules['Hair_Default']; crown=Vector((0,.022,1.70))
for v in wig.data.vertices:v.co-=crown*100
wig.matrix_world.translation=crown
wig['attachment_bone']='Head'
wig['pivot_world_m']=list(crown)

# Child transforms in bone space: origin is the cap center, not an arbitrary head tail.
def socket(name,bone,world):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o)
    o.empty_display_type='ARROWS';o.empty_display_size=5
    o.parent=rig;o.parent_type='BONE';o.parent_bone=bone
    bpy.context.view_layer.update()
    o.matrix_world.translation=Vector(world)
    o['purpose']='Authoring marker; gameplay keeps BoneAttachment3D and item calibration.'
    return o
socket('Socket_Hair','Head',(0,.022,1.70))
socket('Socket_Weapon_R','RightHand',heads['RightHand'])
socket('Socket_Offhand_L','LeftHand',heads['LeftHand'])

# Render-only presentation, outside the selected GLB export.
def simplemat(name,c):
    m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);m.use_nodes=True
    m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*c,1)
    m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.9
    return m
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.035))
ground=bpy.context.object;ground.name='Studio_Ground';ground.data.materials.append(simplemat('Backdrop',(.24,.27,.27)))
def point(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
for name,loc,power,size in [('Key',(-3,-4,5),420,4),('Fill',(3,-2,3),260,3),('Rim',(1,3,4),500,3)]:
    d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size
    o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);o.location=loc;point(o,(0,0,1))
d=bpy.data.cameras.new('ReviewCamera');cam=bpy.data.objects.new('ReviewCamera',d);bpy.context.collection.objects.link(cam)
cam.location=(2.4,-5,2.3);point(cam,(0,0,.90));d.type='ORTHO';d.ortho_scale=2.08
scene=bpy.context.scene;scene.camera=cam;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=1000;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
if scene.world is None:scene.world=bpy.data.worlds.new('StudioWorld')
scene.world.color=(.22,.22,.22);scene.view_settings.view_transform='AgX'
scene.render.image_settings.file_format='PNG'
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_distance=2.7
        area.spaces.active.region_3d.view_location=(0,0,.93)
        area.spaces.active.region_3d.view_rotation=cam.rotation_euler.to_quaternion()
        area.spaces.active.shading.type='MATERIAL'
        area.spaces.active.overlay.show_extras=False
bpy.ops.object.select_all(action='DESELECT')
modules['Body'].select_set(True);bpy.context.view_layer.objects.active=modules['Body']
scene['pilot_status']='New hand-authored procedural meshes, donor rig, outfit modules. Review prototype, not production-approved.'
scene['hair_contract']='Head bone unchanged. Hair_Default can be hidden/replaced. Socket_Hair centered at crown base.'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'castaway_male_v01.blend'))
scene.render.filepath=str(OUT/'review_full.png');bpy.ops.render.render(write_still=True)
cam.location=(.65,-3,1.84);point(cam,(0,-.01,1.63));cam.data.ortho_scale=.47
scene.render.resolution_x=900;scene.render.resolution_y=900
scene.render.filepath=str(OUT/'review_face.png');bpy.ops.render.render(write_still=True)

# Export rig and modules only; all original animation Actions retained.
rig.data.pose_position='POSE'
idle=next(a for a in bpy.data.actions if 'Idle_11' in a.name)
rig.animation_data.action=idle
if idle.slots:rig.animation_data.action_slot=idle.slots[0]
scene.frame_set(int(idle.frame_range[0]))
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
for o in modules.values():o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'castaway_male_v01.glb'),use_selection=True,export_format='GLB',export_animations=True,export_animation_mode='ACTIONS',export_materials='EXPORT',export_extras=True)
report={'bones':len(rig.data.bones),'actions':len(bpy.data.actions),'modules':{name:{'vertices':len(o.data.vertices),'triangles':len(o.data.polygons)} for name,o in modules.items()},'gameplay_changed':False}
(OUT/'build_report.json').write_text(json.dumps(report,indent=2),encoding='utf8')
print('BUILD_OK',json.dumps(report))
