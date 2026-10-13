# Revisión completa de materiales — 12 de octubre de 2026

La dirección elegida es fantasía sobria con materiales reconocibles, colores contenidos y formas legibles junto al personaje. El detalle sirve para distinguir arena, tierra, piedra, nieve y vegetación; no debe convertirse en una alfombra de contornos, reflejos blancos o hojas gigantes. Esta es una primera base integrada y comprobada, no una aprobación artística final de todo el mundo.

## Qué se revisó

Se inspeccionaron visualmente los **348 archivos originales de textura de entorno** disponibles como PNG/JPG, sus tamaños y duplicados. El paquete de suelo contiene 240 archivos, pero sólo 132 imágenes distintas: 100 diseños Ground, 30 Vegetation y dos variantes preparadas. Las copias del catálogo y del banco original no son materiales diferentes. Los otros 108 archivos incluyen albedo, normal, rugosidad/metal, emisión y máscaras de agua, árboles, rocas, construcciones y objetos. También se inspeccionó el atlas 4K del personaje StrongMan y los materiales de 20 modelos GLB del entorno.

Los informes y hojas de contacto están en `art/environment/material_audit_v1/`, en la raíz del repositorio:

- `revision_completa.csv`: crítica de cada uno de los 100 Ground, 30 Vegetation y dos variantes.
- `revision_modelos_agua.csv`: revisión de los otros 108 mapas, distinguiendo su función.
- `environment_inventory.json`: archivos, tamaños, formato y hashes de todos los originales.
- `model_materials.json`: factores declarados por los GLB; no equivale a medición física del material.
- `ground_library_*.png`, `vegetation_library_*.png`, `extra_environment_*.png`: biblioteca completa para comparar.
- `imagegen_prompts.json`: instrucciones exactas de las diez imágenes nuevas.
- `new_materials_tiling.png`: repetición 2×2 de cada base nueva.
- `materiales_bajo_luz_v1.png`: muestras renderizadas en Godot. Las muestras usan StandardMaterial3D; el terreno real usa Terrain3D y sus mezclas.
- `playa_piel_v1.png`, `pasto_interior_v1.png`: capturas del mundo real con los materiales nuevos.

## Diagnóstico crítico

| Familia | Problema del banco anterior | Decisión aplicada |
|---|---|---|
| Arena | Amarillo fuerte, piedras grandes y luces incrustadas. La repetición domina la playa. | Base beige más contenida, grano pequeño y ondulaciones suaves. Variantes teñidas para los slots de costa. |
| Tierra seca | Grietas enormes y placas contorneadas en muchas alternativas. | Tierra granular con pequeñas piedras, tonos marrones menos naranjas. |
| Tierra húmeda | El material llamado húmedo parecía barro seco agrietado. | Humus oscuro, materia orgánica pequeña y rugosidad alta; humedad visual discreta. |
| Pasto | Hojas pintadas demasiado grandes, verde saturado y volumen ilustrado. | Cobertura fina y apagada, más grupos de pasto 3D bajos en terreno apropiado. |
| Musgo y pantano | Bloques verdes que parecen piedra pintada, no suelo orgánico. | Musgo con tierra visible y barro más oscuro. |
| Roca | Lajas gigantes, bordes negros y reflejos ya pintados. | Piedra sedimentaria más suave, menos contraste y escala de mosaico mayor. |
| Ceniza | La imagen se parecía a grava clara. | Polvo mineral gris con partículas pequeñas; separado de nieve. |
| Nieve | Rocas blancas abultadas; además no existía un slot de nieve activo. | Base de nieve fina con acumulaciones suaves; slot propio 24. |
| Empedrado | Saturación roja/naranja, juntas uniformes y facetas brillantes. | Piedra desgastada con juntas discretas. |
| Agua | Sus mapas de normal, altura y espuma son útiles. El mapa de agua ilustrada del banco Ground no es el agua del juego. | Se conserva OceanWater y sus mapas activos. La previsualización esférica Foam003 no se usa como textura de superficie. |
| Piel | El GLB usaba el mismo atlas para albedo y emisión. El personaje se iluminaba a sí mismo y parecía blanco/plástico. | Emisión desactivada, rugosidad 0.67, especular reducido y tinte neutro suave. Atlas original conservado. |

Los mejores candidatos del banco antiguo están marcados como candidatos, no como aprobados sin reservas. Lava, cristales, cráneos y tierras violetas quedan como referencias para lugares concretos. No conviene utilizarlos como relleno genérico para aumentar variedad.

### Modelos del entorno

Las rocas Meshy tienen líneas claras y reflejos dentro del albedo; subir rugosidad no puede borrar esos reflejos. Varios mapas normales son suaves, por lo que el detalle dibujado no produce un relieve equivalente. Los objetos de madera tienen un color más adecuado, pero sus atlas confunden manchas y sombras a distancia corta.

Los árboles 02/04 tienen hojas especialmente saturadas. Los atlas Quaternius y sus siluetas son muy simplificados: incluso con textura nueva se seguirá viendo una copa facetada. El árbol 05 declara emisión blanca y tiene áreas claras en su mapa emisivo; se le asignó material externo sin emisión, manteniendo atlas, UV y normal. La calidad de esas áreas claras del albedo sigue pendiente de una revisión del modelo a distancia de juego.

## Cambios integrados

Hay diez bases nuevas: arena, tierra, tierra húmeda, pasto, musgo, roca, grava, ceniza, empedrado y nieve. Se aplican a **25 slots Terrain3D** mediante variantes de color y escala. Los IDs 0–23 mantienen su posición, de modo que la pintura existente sigue apuntando al mismo tipo de superficie. La nieve se añadió en 24; exportador y perfil polar del pintor automático ya la usan. Esta primera integración conservó la pintura. Después, a petición del usuario, se rehízo la distribución visual del sector del naufragio; la pasada está documentada en `tutorial_coast_v2.md` y conserva alturas, navegación y agujeros.

Los albedos se importan a 512×512 con mipmaps y formato RGB8 uniforme. Los cuatro normales de micrograno se importan a 256×256 RGBA8; el alpha guarda rugosidad. Son mapas técnicos procedurales periódicos, creados en Godot, **no normales completos derivados de las piedras o grietas de las imágenes**. No hay desplazamiento real, parallax ni un mapa de altura completo por material. Terrain3D permite que las dos familias de arrays tengan resoluciones diferentes, manteniendo tamaño/formato uniforme dentro de cada familia. [Preparación de texturas Terrain3D](https://terrain3d.readthedocs.io/en/stable/docs/texture_prep.html).

La variación macro del material era blanca y no cambiaba nada. Ahora introduce una modulación sutil. El sesgo de mipmaps se ajustó a 0.35 para equilibrar detalle y ruido a distancia. Las imágenes generadas permanecen a su resolución fuente; no se destruyeron ni se editaron los PNG del paquete original.

El pasto 3D usa un mesh existente con material mate oliva propio. Se distribuye únicamente sobre los slots 2, 6, 16, 17, 18 y 23, fuera del agua y con normal vertical ≥0.85. No agrega colisiones. Tras la pasada costera hay 5.916 grupos repartidos en 147 lotes MultiMesh; cada lote tiene distancia visible de 65 m. Los grupos miden aproximadamente 20–35 cm y tienen variaciones de giro y tamaño. Es cobertura dispersa: no pretende representar todavía una pradera densa o un bosque acabado. No se guardan instancias sobre la pintura del Terrain3D. Hay además 62 grupos de pasto de duna editables en la escena costera.

La textura del personaje se importa a 2048 para reducir memoria, conservando el archivo fuente 4096 y su UV exacta. No se redibujó con IA una cara sobre un atlas completo, porque eso podría desalinear boca, manos, ojos y ropa. El cuerpo y el pantalón comparten material; afinar piel/ropa por separado requiere máscaras o materiales separados. La geometría muscular y su estilo permanecen.

## Límites y siguiente criterio de revisión

- Una textura más natural no corrige una colina demasiado lisa, la distribución del bioma o el recorte entre dos pinceladas. La pasada costera reduce esas manchas y suaviza las mezclas; otras zonas todavía necesitan revisión propia.
- Los tintes de color ya pintados siguen multiplicando el nuevo albedo. No conviene neutralizarlos a ciegas, porque contienen decisiones anteriores de sombreado y color. [Mapas de color Terrain3D](https://terrain3d.readthedocs.io/en/stable/docs/import_export.html).
- Las diez bases tienen una repetición visual más discreta; todavía hay que revisar recorridos largos, niebla y horas de luz antes de dar por terminado su acabado. La generación de imagen no garantiza un material PBR medido ni bordes perfectos en toda escala.
- La nieve quedó lista y cargada en el sistema. El tutorial costero no tiene nieve pintada: su revisión visible aquí se hace con muestras, no inventando una montaña nevada dentro del sector.
- No se reemplazaron los atlas UV de todos los edificios, objetos o árboles. Quedaron revisados y documentados; sustituirlos bien exige trabajar sobre cada modelo conservando coordenadas y mapas asociados.
- No se promete rendimiento en un PC antiguo. Se redujo la resolución de importación, se usa MultiMesh sin sombras ni colisiones y se limita distancia, pero faltan mediciones en hardware de referencia y perfiles de calidad. Los lotes se crean una vez al cargar cada sector; no se recorren todas las posiciones en cada frame.

La siguiente pasada debe concentrarse en continuidad de las mezclas, densidad de vegetación y escala de árboles/rocas respecto al personaje. La coherencia del conjunto importa más que añadir detalle a cada imagen.

## Recursos editables y validación

`data/materials/natural_terrain_v1.json` contiene los perfiles. Los materiales nativos son `assets/environment/terrain/jueguito_terrain_assets.tres`, `assets/environment/terrain/jueguito_terrain_material.tres`, `resources/characters/strong_man_matte_v1.tres` y `resources/environment/harvestable_tree_05_matte.tres`.

`scripts/tools/editor/setup_terrain3d_resources.gd` reaplica los perfiles al reconstruir la biblioteca; `build_micro_normals.gd` reproduce los mapas técnicos. El autor de perfiles Node está en `scripts/build_natural_material_profiles.js`, en la raíz del repositorio. Ejecutar estos autores restaura sus valores de referencia; no ejecutarlos después de ajustes manuales del dock sin actualizar primero el JSON/autor.

Las pruebas comprueban los 25 IDs, formato/resolución/mipmaps de ambos arrays, rugosidad en alpha, piel y árbol 05 sin emisión, pasto en seco y fuera de paredes, cámara y salto en el terreno real, transición de levantarse y perfil polar sin ceniza. Las capturas se hacen con el renderer D3D12 en la RTX 3050 disponible. Las preferencias de pruebas están aisladas de las preferencias del usuario.
