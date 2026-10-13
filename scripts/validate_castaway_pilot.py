import bpy, json, struct, math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'art/characters/castaway_male_v01'
bpy.context.preferences.filepaths.save_version=0
blob=(OUT/'castaway_male_v01.glb').read_bytes()
length=struct.unpack_from('<I',blob,12)[0]
doc=json.loads(blob[20:20+length])
assert len(doc.get('animations',[]))==20
assert len(doc['skins'][0]['joints'])==24
assert all('COLOR_0' in p['attributes'] for m in doc['meshes'] for p in m['primitives'])
bpy.ops.wm.open_mainfile(filepath=str(OUT/'castaway_male_v01.blend'))
rig=bpy.data.objects['CastawayRig']; scene=bpy.context.scene
rig.data.pose_position='POSE'
meshes=[o for o in bpy.data.objects if o.type=='MESH' and o.get('module')]
report={'glb_animations':[a['name'] for a in doc['animations']],'glb_joints':24,'vertex_colors':True,'samples':[]}
report['hair_origin_world_m']=list(bpy.data.objects['Hair_Default'].matrix_world.translation)
assert (bpy.data.objects['Hair_Default'].matrix_world.translation-Vector((0,.022,1.70))).length<1e-5
for o in meshes:
    assert all(abs(sum(g.weight for g in v.groups)-1)<1e-4 for v in o.data.vertices),o.name
for a in bpy.data.actions:
    rig.animation_data.action=a
    if a.slots:rig.animation_data.action_slot=a.slots[0]
    lo,hi=a.frame_range
    for fraction in [0,.25,.5,.75,1]:
        scene.frame_set(round(lo+(hi-lo)*fraction))
        deps=bpy.context.evaluated_depsgraph_get()
        coords=[o.matrix_world@v.co for o in meshes for v in o.evaluated_get(deps).data.vertices]
        assert all(math.isfinite(c) for v in coords for c in v)
        size=[max(v[i] for v in coords)-min(v[i] for v in coords) for i in range(3)]
        assert max(size)<4,(a.name,size)
        report['samples'].append({'action':a.name,'frame':scene.frame_current,'bounds_m':size})
for key in ['Idle_11','running','Heavy_Hammer_Swing']:
    scene.camera.data.ortho_scale=2.65 if key=='Heavy_Hammer_Swing' else 2.08
    a=next(a for a in bpy.data.actions if key in a.name)
    rig.animation_data.action=a
    if a.slots:rig.animation_data.action_slot=a.slots[0]
    scene.frame_set(round(sum(a.frame_range)/2))
    scene.render.resolution_x=700;scene.render.resolution_y=800;scene.cycles.samples=16
    scene.render.filepath=str(OUT/('pose_'+key+'.png'));bpy.ops.render.render(write_still=True)
# Leave the authoring file ready to preview idle playback.
scene.camera.data.ortho_scale=2.08
a=next(a for a in bpy.data.actions if 'Idle_11' in a.name)
rig.animation_data.action=a
if a.slots:rig.animation_data.action_slot=a.slots[0]
scene.frame_start=int(a.frame_range[0]);scene.frame_end=int(a.frame_range[1]);scene.frame_set(scene.frame_start)
for o in bpy.data.objects:
    if o.name.startswith('Studio_') or o.type in {'LIGHT','CAMERA','EMPTY'}:o.hide_set(True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'castaway_male_v01.blend'))
# Re-import the actual deliverable rather than counting source Actions alone.
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(OUT/'castaway_male_v01.glb'))
imported=next(o for o in bpy.data.objects if o.type=='ARMATURE')
assert len(imported.data.bones)==24
assert len(bpy.data.actions)==20
report['roundtrip_blender']={'bones':len(imported.data.bones),'actions':len(bpy.data.actions)}
(OUT/'validation_report.json').write_text(json.dumps(report,indent=2),encoding='utf8')
print('VALIDATION_OK',len(report['samples']))
