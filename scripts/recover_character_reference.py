"""Recover the existing GLB as a separate editable Blender reference.

Does not modify the gameplay asset or retarget any animation.
Run with Blender --background --factory-startup --python this_file.
"""
import bpy
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = root / 'jueguito/assets/characters/player/models/char_6_c583a7dd/strong_man.glb'
destination = root / 'art/characters/rig_reference'
destination.mkdir(parents=True, exist_ok=True)
target = destination / 'strongman_recovered_reference_v01.blend'
if target.exists():
    raise RuntimeError('Reference already exists; choose a new version instead of overwriting.')
source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
rigs = [obj for obj in bpy.data.objects if obj.type == 'ARMATURE']
meshes = [obj for obj in bpy.data.objects if obj.type == 'MESH']
assert len(rigs) == 1, 'Expected one donor armature'
rig = rigs[0]
for action in bpy.data.actions:
    action.use_fake_user = True
rig.show_in_front = True
rig.data.display_type = 'STICK'
rig['purpose'] = 'Technical donor/reference. New playable silhouettes follow art direction 02.'
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bone_names = [bone.name for bone in rig.data.bones]
action_names = sorted(action.name for action in bpy.data.actions)
assert len(bone_names) == 24
assert len(action_names) == 20
mesh_records = []
bound_count = 0
for obj in meshes:
    skin_modifiers = [m for m in obj.modifiers if m.type == 'ARMATURE']
    bound = any(m.object == rig for m in skin_modifiers)
    bound_count += int(bound)
    mesh_records.append({'name': obj.name, 'vertices': len(obj.data.vertices),
                         'bound_to_rig': bound,
                         'users_collection': [c.name for c in obj.users_collection],
                         'vertex_groups': len(obj.vertex_groups),
                         'dimensions': list(obj.dimensions)})
assert bound_count > 0, 'No skinned character mesh found'
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(target))
bpy.ops.wm.open_mainfile(filepath=str(target))
assert sorted(a.name for a in bpy.data.actions) == action_names
reopened_rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
assert [b.name for b in reopened_rig.data.bones] == bone_names
assert hashlib.sha256(source.read_bytes()).hexdigest() == source_hash
report = {'source': str(source), 'source_sha256': source_hash,
          'blend': str(target), 'blender': bpy.app.version_string,
          'bones': bone_names, 'actions': action_names, 'meshes': mesh_records,
          'save_reopen_verified': True, 'source_unchanged': True,
          'limits': 'Structure and persistence verified; new meshes, garment weights, retargeting and visual animation QA remain to be done.'}
(destination / 'recovery_report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print('RECOVERY_OK ' + json.dumps(report))
