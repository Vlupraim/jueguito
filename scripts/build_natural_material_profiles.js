// Asset authoring only; preserve original source library and painted texture IDs.
const fs=require('fs'), path=require('path');
const root=path.resolve(__dirname,'..','jueguito');
const base='assets/environment/terrain/textures/natural_v1';
const definitions=[
 ['00_TierraSeca','soil','earth',[1,1,1],0.68],
 ['01_Arena','sand','fine',[0.93,0.92,0.90],0.68],
 ['02_Pasto','grass','grass',[0.94,1,0.92],0.68],
 ['03_TierraHumeda','damp_soil','earth',[1,1,1],0.68],
 ['04_Roca','rock','stone',[1,1,1],0.45],
 ['05_Arcano','rock','stone',[0.83,0.88,1],0.48],
 ['06_PastoSombrio','grass','grass',[0.80,0.92,0.83],0.68],
 ['07_Pantano','damp_soil','earth',[0.83,0.94,0.83],0.68],
 ['08_TierraGrisGravilla','gravel','earth',[0.88,0.92,0.98],0.68],
 ['09_ArenaRosaGravilla','sand','fine',[0.99,0.88,0.82],0.68],
 ['10_ArenaClaraPiedras','gravel','earth',[1,0.97,0.89],0.68],
 ['11_TierraOcrePiedras','soil','earth',[1,0.95,0.86],0.68],
 ['12_TierraRojaFina','soil','earth',[1,0.83,0.76],0.68],
 ['13_TierraRojaGrava','gravel','earth',[1,0.83,0.76],0.68],
 ['14_RocaGrisLajas','rock','stone',[0.91,0.96,1],0.45],
 ['15_CenizaGrisGravilla','ash','fine',[1,1,1],0.68],
 ['16_RocaMarronMusgo','moss','grass',[0.90,0.96,0.86],0.68],
 ['17_PastoRocasDispersas','moss','grass',[0.98,1,0.92],0.68],
 ['18_MusgoRocasGrandes','moss','grass',[0.85,0.91,0.85],0.68],
 ['19_RocaCalizaClara','rock','stone',[1,1,0.94],0.45],
 ['20_RocaMarronLajas','rock','stone',[1,0.93,0.84],0.45],
 ['21_CantosMarronesHumedos','gravel','stone',[0.77,0.76,0.71],0.68],
 ['22_EmpedradoRojo','flagstone','stone',[1,0.90,0.84],0.55],
 ['23_PastoRocasSombrio','moss','grass',[0.76,0.85,0.78],0.68],
 ['24_Nieve','snow','fine',[1,1,1],0.68],
];
const profiles=definitions.map(([name,texture,normal,tint,scale],id)=>({id,name,albedo:`res://${base}/${texture}.png`,normal:`res://${base}/micro_${normal}_normal_roughness.png`,tint,uv_scale:scale,normal_depth:.6,ao_strength:.25,roughness: texture==='damp_soil'?-.04:0}));
const file=path.join(root,'assets/environment/terrain/jueguito_terrain_assets.tres');
const original=fs.readFileSync(file,'utf8').replace(/\r\n/g,'\n');
let edited=original.replace(/\[ext_resource type="Texture2D"[^\n]+\]\r?\n/g,'');
const textureResources=[...new Set(profiles.flatMap(p=>[p.albedo,p.normal]))];
const resources=textureResources.map((p,i)=>`[ext_resource type="Texture2D" path="${p}" id="natural_${i}"]`).join('\n');
edited=edited.replace(/(\[gd_resource[^\n]*\]\r?\n)/,`$1\n${resources}\n`);
const ids=[];
edited=edited.replace(/\[sub_resource type="Terrain3DTextureAsset" id="([^"]+)"\][\s\S]*?(?=\n\[)/g,(block,id)=>{
 const slot=Number((block.match(/^id = (\d+)$/m)||[])[1]||0); ids[slot]=id;
 const p=profiles[slot];
 return textureBlock(id,p);
});
function textureBlock(id,p){return `[sub_resource type="Terrain3DTextureAsset" id="${id}"]\nname = "${p.name}"\nid = ${p.id}\nalbedo_texture = ExtResource("natural_${textureResources.indexOf(p.albedo)}")\nnormal_texture = ExtResource("natural_${textureResources.indexOf(p.normal)}")\nalbedo_color = Color(${p.tint.join(', ')}, 1)\nnormal_depth = ${p.normal_depth}\nao_strength = ${p.ao_strength}\nroughness = ${p.roughness}\nuv_scale = ${p.uv_scale}\ndetiling_rotation = 0.298\ndetiling_shift = 0.255\n`;}
if(!ids[24]) {
 ids[24]='Terrain3DTextureAsset_natural_snow';
 edited=edited.replace('[resource]',`${textureBlock(ids[24],profiles[24])}\n[resource]`);
}
edited=edited.replace(/^texture_list = .+$/m,`texture_list = Array[Terrain3DTextureAsset]([${ids.map(id=>`SubResource("${id}")`).join(', ')}])`);
fs.mkdirSync(path.join(root,'data/materials'),{recursive:true});
fs.writeFileSync(path.join(root,'data/materials/natural_terrain_v1.json'),JSON.stringify(profiles,null,2));
fs.writeFileSync(file,edited);
// Configure generated diffuse images at matching runtime size; originals stay high-res.
for(const p of fs.readdirSync(path.join(root,base)).filter(n=>n.endsWith('.png'))){
 const source=`res://${base}/${p}`, hash=require('crypto').createHash('md5').update(source).digest('hex');
 const normal=p.includes('normal_roughness');
 fs.writeFileSync(path.join(root,base,p+'.import'),`[remap]\nimporter="texture"\ntype="CompressedTexture2D"\npath="res://.godot/imported/${p}-${hash}.ctex"\n[deps]\nsource_file="${source}"\ndest_files=["res://.godot/imported/${p}-${hash}.ctex"]\n[params]\ncompress/mode=0\ncompress/normal_map=2\ncompress/channel_pack=0\nmipmaps/generate=true\nprocess/size_limit=${normal?0:512}\ndetect_3d/compress_to=0\n`);
}
console.log(`Authored ${profiles.length} texture profiles; IDs 0–23 preserved, snow appended at 24.`);
