import bpy, json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(root/'art/characters/rig_reference/strongman_recovered_reference_v01.blend'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
body=bpy.data.objects['char1']
print('GEOMETRY',json.dumps({'rig_matrix':[list(v) for v in rig.matrix_world], 'body_matrix':[list(v) for v in body.matrix_world], 'body_bounds':[list(v) for v in body.bound_box], 'bones':{b.name:{'head':list(rig.matrix_world@b.head_local),'tail':list(rig.matrix_world@b.tail_local)} for b in rig.data.bones}}))
