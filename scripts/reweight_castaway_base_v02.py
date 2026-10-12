"""Refresh binding from authoring functions without rerunning geometry/texture bake."""
import bpy,ast,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'art/characters/castaway_base_v02'
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.open_mainfile(filepath=str(OUT/'castaway_base_v02.blend'))
rig=bpy.data.objects['CastawayRig'];rig.data.pose_position='REST'
heads={b.name:rig.matrix_world@b.head_local for b in rig.data.bones}
tree=ast.parse((ROOT/'scripts/build_castaway_base_v02.py').read_text(encoding='utf8'))
tree.body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in {'clamp','smooth','spine','weights'}]
exec(compile(tree,'binding_functions','exec'))
body=bpy.data.objects['Body_Base'];indices=list(range(len(body.data.vertices)))
for g in body.vertex_groups:
    if g.name in rig.data.bones:g.remove(indices)
groups={g.name:g for g in body.vertex_groups}
for v in body.data.vertices:
    for name,w in weights(v.co/100).items():
        if w<1e-6:continue
        if name not in groups:groups[name]=body.vertex_groups.new(name=name)
        groups[name].add([v.index],w,'REPLACE')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'castaway_base_v02.blend'))
print('BINDING_UPDATED')
