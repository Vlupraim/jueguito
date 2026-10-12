"""Export and verify the v02 reference-driven base without changing the game."""
import bpy,json,struct,math,hashlib
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'art/characters/castaway_base_v02'
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/characters/rig_reference/strongman_recovered_reference_v01.blend'))
donor=next(o for o in bpy.data.objects if o.type=='ARMATURE')
rest={b.name:[list(row) for row in b.matrix_local] for b in donor.data.bones}
bpy.ops.wm.open_mainfile(filepath=str(OUT/'castaway_base_v02.blend'))
rig=bpy.data.objects['CastawayRig'];body=bpy.data.objects['Body_Base'];cloth=bpy.data.objects['Base_Covering'];scene=bpy.context.scene
for o in bpy.data.objects:o.hide_set(False)
assert set(rest)==set(rig.data.bones.keys())
assert all(abs(rest[b.name][i][j]-b.matrix_local[i][j])<1e-6 for b in rig.data.bones for i in range(4) for j in range(4))
for o in [body,cloth]:
    bone_indices={g.index for g in o.vertex_groups if g.name in rig.data.bones}
    assert all(abs(sum(g.weight for g in v.groups if g.group in bone_indices)-1)<1e-4 for v in o.data.vertices),o.name
for v in body.data.vertices:
    p=v.co/100
    if abs(p.x)>.36 and p.z<.91:
        hand='LeftHand' if p.x>0 else 'RightHand'
        assert sum(g.weight for g in v.groups if body.vertex_groups[g.group].name==hand)>.999,('Fingertip is not rigidly attached to its hand',list(p),[(body.vertex_groups[g.group].name,g.weight) for g in v.groups])
report={'donor_rest_matrices_unchanged':True,'bone_count':len(rest),'sampled_frames':[],'modules':['Body_Base','Base_Covering'],'hair':'Bald base; Head attachment marker only. No new hairstyle included.'}
rig.data.pose_position='POSE'
for a in bpy.data.actions:
    rig.animation_data.action=a
    if a.slots:rig.animation_data.action_slot=a.slots[0]
    lo,hi=a.frame_range
    for t in [0,.25,.5,.75,1]:
        scene.frame_set(round(lo+(hi-lo)*t));deps=bpy.context.evaluated_depsgraph_get()
        coords=[o.matrix_world@v.co for o in [body,cloth] for v in o.evaluated_get(deps).data.vertices]
        size=[max(v[i] for v in coords)-min(v[i] for v in coords) for i in range(3)]
        assert all(math.isfinite(c) for v in coords for c in v)
        assert max(size)<4,(a.name,size)
        report['sampled_frames'].append({'action':a.name,'frame':scene.frame_current,'size_m':size})
for key in ['Idle_11','running','Heavy_Hammer_Swing']:
    a=next(a for a in bpy.data.actions if key in a.name);rig.animation_data.action=a
    if a.slots:rig.animation_data.action_slot=a.slots[0]
    scene.frame_set(round(sum(a.frame_range)/2));scene.camera.data.ortho_scale=2.65 if key=='Heavy_Hammer_Swing' else 2.02
    scene.render.resolution_x=800;scene.render.resolution_y=950;scene.cycles.samples=20
    scene.render.filepath=str(OUT/('pose_'+key+'.png'));bpy.ops.render.render(write_still=True)
a=next(a for a in bpy.data.actions if 'Idle_11' in a.name);rig.animation_data.action=a
if a.slots:rig.animation_data.action_slot=a.slots[0]
scene.frame_start=int(a.frame_range[0]);scene.frame_end=int(a.frame_range[1]);scene.frame_set(scene.frame_start);scene.camera.data.ortho_scale=2.02
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);body.select_set(True);cloth.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'castaway_base_v02.glb'),use_selection=True,export_format='GLB',export_apply=True,export_animations=True,export_animation_mode='ACTIONS',export_vertex_color='NONE',export_extras=True)
blob=(OUT/'castaway_base_v02.glb').read_bytes();n=struct.unpack_from('<I',blob,12)[0];doc=json.loads(blob[20:20+n])
assert len(doc['animations'])==20;assert len(doc['skins'][0]['joints'])==24
assert len(doc['images'])==2
assert all('COLOR_0' not in p['attributes'] for m in doc['meshes'] for p in m['primitives'])
report['glb']={'animations':[a['name'] for a in doc['animations']],'joints':24,'embedded_textures':len(doc['images']),'triangles':sum(doc['accessors'][p['indices']]['count']//3 for m in doc['meshes'] for p in m['primitives'])}
for o in bpy.data.objects:
    if o.type in {'LIGHT','CAMERA','EMPTY'} or o.name=='Studio_Ground':o.hide_set(True)
rig.hide_set(True);body.select_set(True);bpy.context.view_layer.objects.active=body
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'castaway_base_v02.blend'))
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(OUT/'castaway_base_v02.glb'))
assert len(next(o for o in bpy.data.objects if o.type=='ARMATURE').data.bones)==24
assert len(bpy.data.actions)==20
report['roundtrip_blender']='passed'
source=ROOT/'jueguito/assets/characters/player/models/char_6_c583a7dd/strong_man.glb'
report['original_sha256']=hashlib.sha256(source.read_bytes()).hexdigest()
assert report['original_sha256']=='0d0b01d2835678c05e155a6bd3734212b536c7f6a27b88199a9705a7e0258730'
(OUT/'validation_report.json').write_text(json.dumps(report,indent=2),encoding='utf8')
print('VALIDATION_OK',report['glb'])
