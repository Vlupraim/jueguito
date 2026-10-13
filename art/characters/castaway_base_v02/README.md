# Base masculina v02 — referencia aprobada v04

Segundo intento de modelado, 2026-09-14. Prototipo para revisión artística y técnica; no sustituye el personaje del juego.

Resultado verificado: 21.873 triángulos visibles en el GLB, dos mallas, dos texturas incluidas, 24 huesos y 20 animaciones. Pasaron la reimportación en Blender y la importación mínima en Godot 4.7. Se muestrearon 100 poses para controles numéricos y se inspeccionaron renders de reposo, carrera y ataque elevado. Persisten simplificaciones y defectos visuales en articulaciones, especialmente rodillas flexionadas; estos controles no significan aprobación para producción.

## Archivos

- `castaway_base_v02.blend`: cuerpo completo editable, cobertura independiente y esqueleto original. Texturas empaquetadas.
- `castaway_base_v02.glb`: versión de intercambio con la cobertura base puesta, dos materiales con texturas incluidas y las animaciones del donante.
- `body_basecolor.png`, `sackcloth_basecolor.png`: texturas horneadas desde los materiales de autoría.
- `review_full.png`, `review_face.png`: renders del modelo real en reposo.
- `pose_Idle_11.png`, `pose_running.png`, `pose_Heavy_Hammer_Swing.png`: revisión de poses reales.
- `build_report.json`, `validation_report.json`, `godot_import_report.json`: informes producidos por los scripts correspondientes; consultar estos archivos para resultados de las comprobaciones, no inferirlos de este documento.

## Estructura

`Body_Base` conserva cabeza calva, torso, manos y pies. `Base_Covering` es una prenda separada de tela basta, sin pantalones, botas, cinturón ni peinado incorporado.

El modificador reversible `Hide_under_base_covering` oculta geometría cubierta. Desactivarlo permite editar la anatomía completa. Para cambiar de vestuario hay que adaptar la máscara de cobertura; ese comportamiento todavía no está implementado en el juego. El GLB aplica la máscara y, por lo tanto, no contiene la anatomía oculta de esta combinación. La fuente completa está en el archivo Blender.

El esqueleto mantiene los nombres y matrices de reposo del Strongman, incluidos `Head`, `RightHand` y `LeftHand`. Los marcadores `Socket_Hair`, `Socket_Weapon_R` y `Socket_Offhand_L` son ayudas de autoría; no sustituyen los `BoneAttachment3D` ni las calibraciones de objetos de Godot. Todavía no se ha creado un peinado nuevo para esta base.

## Acabado y límites

La geometría fue construida en Blender por script, con unión volumétrica y simplificación, sin usar Meshy. El rostro pintado procede de una proyección de la vista frontal de la referencia v04, integrada con el color del cuerpo y horneada en UV. La tela toma pigmentos de una zona interior de la misma referencia. La imagen original permanece intacta.

Este procedimiento mejora la relación con la referencia, pero no equivale a una textura pintada y corregida desde todos los ángulos. El perfil, las orejas y la transición de la cara al resto de la cabeza necesitan revisión artística. Los hombros, manos y pies conservan simplificaciones visibles. El cuerpo usa una topología triangulada de prototipo, no una retopología final optimizada para todas las deformaciones.

El donante no tiene huesos individuales de dedos. Las manos siguen sus huesos de mano de forma rígida: faltan poses de agarre específicas y su comprobación con espadas, escudos y armas de dos manos. Preservar las animaciones no garantiza que cada arma o cada cruce de la tela quede resuelto.

La validación numérica muestrea cinco momentos por animación, comprueba pesos y límites de tamaño, conserva las matrices del esqueleto y realiza una reimportación. No es una comprobación exhaustiva de colisiones, clipping o calidad visual de todos los fotogramas. La prueba mínima de Godot verifica importación y recursos; no es una integración del personaje en el controlador del juego.

## Reproducción

Ejecutar secuencialmente, esperando la salida de cada proceso antes del siguiente:

1. Blender en segundo plano con `scripts/build_castaway_base_v02.py`.
2. Blender en segundo plano con `scripts/verify_castaway_base_v02.py`.
3. Godot en modo headless, usando `import_check` como proyecto y `check.gd` como script. Pasar `--log-file` con una ruta escribible dentro de esta carpeta: la primera ejecución no pudo crear el directorio de logs del perfil y falló antes de importar. Con el log local pasó; el aviso sobre certificados del entorno no impidió esta prueba de archivos locales.

No ejecutar construcción y validación simultáneamente: ambos guardan el archivo de autoría.
