// Authoring utility: emits editable Godot scenes and SVG resources, never runs in-game.
const fs = require('fs');
const path = require('path');
const base = path.resolve(__dirname, '../jueguito');
function write(p, text) { fs.mkdirSync(path.dirname(path.join(base,p)),{recursive:true}); fs.writeFileSync(path.join(base,p), text); }
const art='assets/ui/inventory/v1';
const motifs = {
  bag:'<path d="M31 38h34l6 38H25zM36 38v-9a12 12 0 0 1 24 0v9M35 52h26M39 61h18"/>',
  head:'<path d="M23 53v-9a25 25 0 0 1 50 0v27l-13 7V50H36v28l-13-7zM48 20v24M29 42h38"/>',
  cape:'<path d="M37 22h22l17 53-22-5-6 8-6-8-22 5zM37 22l11 15 11-15M48 37v25"/>',
  main_hand:'<path d="M31 68l35-45 7-3-1 9-35 45M28 58l20 16M28 70l-8 10M20 72l8 8"/>',
  offhand:'<path d="M48 20l25 9-4 27c-3 11-12 18-21 24-9-6-18-13-21-24l-4-27zM48 28v39M32 45h32"/>',
  chest:'<path d="M34 22l14 6 14-6 16 16-13 13-5-7v34H36V44l-5 7-13-13zM48 29v39M39 52h18"/>',
  consumable:'<path d="M39 19h18v13l12 19v20c0 9-42 9-42 0V51l12-19zM34 56h28M38 19h20M44 66h8"/>',
  feet:'<path d="M35 20h25l-3 33 18 13v12H23V65l10-5zM36 30h19M35 43h18M24 68h39"/>',
  food:'<path d="M47 35c-16-17-33 1-26 22 6 18 15 26 26 16 11 10 20 2 26-16 7-21-10-39-26-22zM47 35c-4-10 0-18 9-22M50 27c8-10 17-9 23-3-6 8-15 10-23 3"/>',
  bow:'<path d="M29 20q43 28 0 56M29 20v56M21 48h53M65 39l9 9-9 9"/>',
  tree:'<path d="M48 16L23 48h12L19 66h23v15h12V66h23L61 48h12z"/>',
  pick:'<path d="M28 80l35-48M19 33q25-29 59-7l-25 8-17 18M42 38l11 8"/>',
  compass:'<circle cx="48" cy="48" r="29"/><path d="M57 31l-3 23-23 11 12-24zM48 13v9M48 74v9M13 48h9M74 48h9"/>',
  hammer:'<path d="M28 78l29-42M35 21l13-7 31 23-12 16zM35 21l-10 14 22 16"/>',
  eye:'<path d="M14 48q34-41 68 0-34 41-68 0z"/><circle cx="48" cy="48" r="12"/><path d="M23 72l50-48"/>',
  crown:'<path d="M22 29l16 17 10-25 10 25 16-17-6 40H28zM28 78h40"/>',
  scroll:'<path d="M32 21h36q16 0 10 16H38V24c0-11-20-11-20 0v37h42v12c0 15 20 15 20 0H60M31 47h25M31 55h19"/>',
  leaf:'<path d="M25 68C7 29 42 14 77 19c-1 36-18 68-52 49zM22 79l41-43M35 59l-5-15M49 46l16 4"/>',
  ring:'<circle cx="48" cy="55" r="23"/><path d="M34 23l14-9 14 9-5 15H39zM39 23h18M48 15v19"/>',
  boat:'<path d="M16 62h66l-13 17H29zM47 19v43M52 24l22 27H52M42 27L25 52h17"/>',
};
function icon(motif, color='#ead29c') { return `<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96"><defs><linearGradient id="metal" x2="0" y2="1"><stop stop-color="#fff0c5"/><stop offset=".5" stop-color="${color}"/><stop offset="1" stop-color="#a07841"/></linearGradient></defs><g transform="translate(1 2)" fill="none" stroke="#130f0b" stroke-width="6" stroke-linecap="round" stroke-linejoin="round">${motif}</g><g fill="none" stroke="url(#metal)" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">${motif}</g></svg>`; }
for(const [name,motif] of Object.entries(motifs)) write(`${art}/equipment_${name}.svg`,icon(motif));
write(`${art}/two_hand_reserved.svg`,icon('<path d="M26 32h16v25H26zM54 32h16v25H54zM42 44h12M22 65h52M29 74h38"/>'));
for(const [state,center,rim] of [['normal','#253039','#bd9f65'],['hover','#344e57','#f2d695'],['empty','#292c2d','#776b54']]) {
write(`${art}/slot_${state}.svg`,`<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96"><defs><linearGradient id="face" x2="0" y2="1"><stop stop-color="${center}"/><stop offset="1" stop-color="#11191e"/></linearGradient><linearGradient id="rim" x2="1" y2="1"><stop stop-color="#f6dfac"/><stop offset=".5" stop-color="${rim}"/><stop offset="1" stop-color="#5e472d"/></linearGradient></defs><rect x="2" y="2" width="92" height="92" rx="10" fill="#171310" stroke="#201b14" stroke-width="3"/><rect x="5" y="5" width="86" height="86" rx="8" fill="url(#rim)"/><rect x="9" y="9" width="78" height="78" rx="5" fill="url(#face)" stroke="#0c1114" stroke-width="2"/><path d="M14 21v-7h7M75 14h7v7M82 75v7h-7M21 82h-7v-7" fill="none" stroke="${rim}" stroke-width="1.5"/></svg>`);
write(`resources/ui/inventory/slot_${state}.tres`,`[gd_resource type="StyleBoxTexture" load_steps=2 format=3]\n[ext_resource type="Texture2D" path="res://${art}/slot_${state}.svg" id="1"]\n[resource]\ntexture = ExtResource("1")\ntexture_margin_left = 12.0\ntexture_margin_top = 12.0\ntexture_margin_right = 12.0\ntexture_margin_bottom = 12.0\ncontent_margin_left = 5.0\ncontent_margin_top = 5.0\ncontent_margin_right = 5.0\ncontent_margin_bottom = 5.0\n`);
}
write('resources/ui/inventory/parchment_panel.tres',`[gd_resource type="StyleBoxTexture" load_steps=2 format=3]\n[ext_resource type="Texture2D" path="res://${art}/parchment_panel.png" id="1"]\n[resource]\ntexture = ExtResource("1")\ncontent_margin_left = 18.0\ncontent_margin_top = 34.0\ncontent_margin_right = 18.0\ncontent_margin_bottom = 24.0\n`);
const families=[
{name:'MARCIALES',color:'#d59476',icon:'main_hand',angle:225,groups:{Armas:['Espadas','Arcos','Armas de asta','Hachas','Dagas'],Protección:['Escudos','Tela','Cuero','Metal']}},
{name:'MUNDO',color:'#86c6a5',icon:'tree',angle:315,groups:{Recolección:['Silvicultura','Minería','Botánica','Caza','Pesca'],Aventura:['Exploración','Supervivencia','Navegación','Rastreo'],Domadura:['Captura','Crianza','Entrenamiento']}},
{name:'OFICIO',color:'#ddbe7b',icon:'hammer',angle:135,groups:{Refinado:['Carpintería','Metalurgia','Curtiduría','Textilería'],Fabricación:['Herrería','Arquería','Sastrería','Construcción naval','Alquimia'],Servicios:['Reparación','Encantamiento','Calidad']}},
{name:'INFLUENCIA',color:'#a9a2d4',icon:'crown',angle:45,groups:{Comercio:['Transporte','Contratos','Tasación'],Espionaje:['Observación','Infiltración','Falsificación','Sabotaje'],Liderazgo:['Mando','Diplomacia','Gobierno','Moral']}}
];
const icons={Espadas:'main_hand',Arcos:'bow',Escudos:'offhand',Silvicultura:'tree','Minería':'pick','Botánica':'leaf','Exploración':'compass','Navegación':'boat','Herrería':'hammer','Construcción naval':'boat',Alquimia:'consumable','Observación':'eye','Liderazgo':'crown',Contratos:'scroll',Gobierno:'crown','Encantamiento':'ring'};
const root={x:2500,y:2750};
const nodes=[], edges=[];
function add(name,family,pos,size,icon,kind='mastery',description='Recorrido de maestría. Requisitos y efectos pendientes de balance.') {
 const id=`Node${nodes.length}`; const n={id,name,family,x:pos.x,y:pos.y,size,icon,kind,description};nodes.push(n);return n;
}
function polar(angle,r){const a=angle*Math.PI/180;return {x:root.x+Math.cos(a)*r,y:root.y+Math.sin(a)*r};}
function connect(a,b,color,width=5){edges.push({a,b,color,width});}
const origin=add('YGGDRASIL','Origen',root,180,'tree','root','El tronco común. Elige una rama para explorar sus maestrías.');
for(const family of families){
 const hub=add(family.name,family.name,polar(family.angle,635),150,family.icon,'family',`Rama ${family.name.toLowerCase()}. No limita el acceso a las otras ramas.`);connect(origin,hub,family.color,9);
 const groups=Object.entries(family.groups);
 groups.forEach(([group,leaves],gi)=>{
  const ga=family.angle+(gi-(groups.length-1)/2)*20;
  const gn=add(group,family.name,polar(ga,1180),106,family.icon,'group');connect(hub,gn,family.color,6);
  leaves.forEach((name,li)=>{
   const la=ga+(li-(leaves.length-1)/2)*4.0;
   const ln=add(name,family.name,polar(la,1600),88,icons[name]||family.icon);connect(gn,ln,family.color,4);
   let last=ln;
   ['Práctica','Dominio','Legado'].forEach((tier,ti)=>{
    const rank=add(`${name} · ${tier}`,family.name,polar(la,1800+ti*190),60,icons[name]||family.icon,'rank',`Hito ${tier.toLowerCase()} del recorrido de ${name}. Vista conceptual; desbloqueo y efectos pendientes.`);connect(last,rank,family.color,3);last=rank;
   });
  });
 });
}
write('data/mastery/yggdrasil_board_v1.json',JSON.stringify({version:1,canvas:[5000,5000],root,nodes},null,2));
const routes=edges.map(({a,b,color,width})=>`<path d="M${a.x.toFixed(1)} ${a.y.toFixed(1)} Q${((a.x+b.x)/2+35).toFixed(1)} ${((a.y+b.y)/2-35).toFixed(1)} ${b.x.toFixed(1)} ${b.y.toFixed(1)}" stroke="${color}" stroke-width="${width}" opacity=".65"/>`).join('');
write('assets/ui/mastery/v1/branch_routes.svg',`<svg xmlns="http://www.w3.org/2000/svg" width="2500" height="2500" viewBox="0 0 5000 5000"><g fill="none" stroke-linecap="round">${routes}</g></svg>`);
write('assets/ui/mastery/v1/selected_ring.svg','<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128"><circle cx="64" cy="64" r="59" fill="none" stroke="#fff0b1" stroke-width="4"/><path d="M64 0l6 9-6 5-6-5zM64 128l6-9-6-5-6 5zM0 64l9-6 5 6-5 6zM128 64l-9-6-5 6 5 6z" fill="#fff0b1"/></svg>');
const resources=[['bg','Texture2D','assets/ui/mastery/v1/yggdrasil_atlas.png'],['frame','Texture2D','assets/ui/mastery/v1/node_medallion.png'],['routes','Texture2D','assets/ui/mastery/v1/branch_routes.svg'],['selected','Texture2D','assets/ui/mastery/v1/selected_ring.svg'],...Object.keys(motifs).map(k=>[k,'Texture2D',`${art}/equipment_${k}.svg`])];
let scene=`[gd_scene load_steps=${resources.length+1} format=3]\n\n`+resources.map(([id,type,p])=>`[ext_resource type="${type}" path="res://${p}" id="${id}"]`).join('\n')+'\n\n[node name="YggdrasilBoard" type="Control"]\nlayout_mode = 0\noffset_right = 5000.0\noffset_bottom = 5000.0\nmouse_filter = 2\n';
for(const [name,texture] of [['Artwork','bg'],['Paths','routes']]) scene+=`\n[node name="${name}" type="TextureRect" parent="."]\nlayout_mode = 0\noffset_right = 5000.0\noffset_bottom = 5000.0\nmouse_filter = 2\ntexture = ExtResource("${texture}")\nexpand_mode = 1\n${name === 'Artwork' ? 'self_modulate = Color(0.45,0.45,0.45,1)\n' : ''}`;
for(const n of nodes){
 const color=families.find(f=>f.name===n.family)?.color||'#f0d599';const rgb=color.match(/\w\w/g).map(x=>parseInt(x,16)/255);
 scene+=`\n[node name="${n.id}" type="Control" parent="."]\nlayout_mode = 0\noffset_left = ${n.x-n.size/2}\noffset_top = ${n.y-n.size/2}\noffset_right = ${n.x+n.size/2}\noffset_bottom = ${n.y+n.size/2}\nmouse_filter = 2\nmetadata/title = ${JSON.stringify(n.name)}\nmetadata/family = ${JSON.stringify(n.family)}\nmetadata/description = ${JSON.stringify(n.description)}\nmetadata/kind = ${JSON.stringify(n.kind)}\n`;
 scene+=`\n[node name="Medallion" type="TextureRect" parent="${n.id}"]\nlayout_mode = 1\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\nmouse_filter = 2\ntexture = ExtResource("frame")\nexpand_mode = 1\nstretch_mode = 5\nself_modulate = Color(${rgb.join(',')},1)\n`;
 scene+=`\n[node name="Icon" type="TextureRect" parent="${n.id}"]\nlayout_mode = 0\noffset_left = ${n.size*.25}\noffset_top = ${n.size*.25}\noffset_right = ${n.size*.75}\noffset_bottom = ${n.size*.75}\nmouse_filter = 2\ntexture = ExtResource("${n.icon}")\nexpand_mode = 1\nstretch_mode = 5\n`;
 scene+=`\n[node name="Selection" type="TextureRect" parent="${n.id}"]\nvisible = false\nlayout_mode = 1\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\nmouse_filter = 2\ntexture = ExtResource("selected")\nexpand_mode = 1\n`;
 if(n.kind!=='rank')scene+=`\n[node name="Title" type="Label" parent="${n.id}"]\nlayout_mode = 0\noffset_left = -65.0\noffset_top = ${n.size+8}\noffset_right = ${n.size+65}\noffset_bottom = ${n.size+36}\nmouse_filter = 2\ntext = ${JSON.stringify(n.name)}\nhorizontal_alignment = 1\ntheme_override_colors/font_color = Color(${rgb.join(',')},1)\ntheme_override_colors/font_outline_color = Color(0.02,0.03,0.04,1)\ntheme_override_constants/outline_size = 6\ntheme_override_font_sizes/font_size = ${n.kind==='family'?28:n.kind==='root'?26:18}\n`;
}
write('scenes/ui/mastery/yggdrasil_board_v1.tscn',scene);
console.log(`Authored ${nodes.length} nodes, ${edges.length} paths and reusable inventory SVG assets.`);
