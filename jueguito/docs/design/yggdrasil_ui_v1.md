# Yggdrasil: interfaz de maestrías e inventario v1

## Lectura de los rumbos

El tronco común abre cuatro recorridos. Marciales ocupa la copa izquierda,
Mundo la copa derecha, Oficio las raíces izquierdas e Influencia las derechas.
Cada rumbo tiene posición, nombre, emblema y color propios; reconocerlo no
depende solamente del color. El dibujo permanece atenuado bajo los caminos.

La vista comienza cerca del origen, con las cuatro decisiones principales
visibles. La rueda hace zoom sobre el punto del cursor y el botón izquierdo
arrastra el lienzo. Un clic corto selecciona un nodo y muestra su ficha. Los
accesos superiores centran cada familia; Origen vuelve al tronco y Ver todo
muestra el árbol completo. Los nombres de familia conservan un tamaño legible
en la vista general y los nombres menores aparecen al acercar el zoom.

El lienzo mide 5000 × 5000 unidades de interfaz. Contiene 192 nodos guardados
en una escena nativa de Godot, con tres hitos conceptuales por recorrido:
Práctica, Dominio y Legado. Esta versión permite explorar la estructura; todavía
no asigna efectos, requisitos de desbloqueo ni experiencia persistente. La
referencia de reglas continúa siendo `mastery_tree.md`.

## Recursos editables

- `res://scenes/ui/mastery/yggdrasil_board_v1.tscn`: abrir como escena 2D en
  Godot. Los nodos son Controls con icono, medallón, título, selección y metadatos
  de ficha. Se pueden mover y editar individualmente.
- `res://assets/ui/mastery/v1/yggdrasil_atlas.png`: ilustración conceptual del
  árbol, sin texto ni botones incrustados.
- `res://assets/ui/mastery/v1/node_medallion.png`: medallón con transparencia
  exterior; todos los nodos comparten la misma textura.
- `res://assets/ui/mastery/v1/branch_routes.svg`: conexiones guardadas como
  recurso vectorial, rasterizado a 2500 px y estirado al lienzo de 5000 unidades.
- `res://data/mastery/yggdrasil_board_v1.json`: referencia de títulos,
  posiciones y metadatos de la composición inicial.
- `res://assets/ui/inventory/v1/`: panel de pergamino, marcos, pictogramas de
  equipo y símbolo de reserva para armas de dos manos.
- `res://resources/ui/`: estilos de inventario y panel de detalle de maestrías.

El juego carga esos recursos guardados. El script de autoría
`../scripts/build_ui_resources_v1.js` (desde la raíz superior del repositorio)
produjo la composición inicial y los SVG. No se ejecuta durante el juego.
Volver a ejecutarlo reemplaza los SVG, metadatos y escena que produce, por lo
que deben conservarse aparte las modificaciones manuales del editor.

## Inventario

El panel usa pergamino con ornamentos de latón y ranuras oscuras. Equipo y
mochila comparten el tratamiento de sus marcos. Los iconos de la mochila tienen
un área centrada independiente de las cantidades y del indicador de equipado.

La espada inicial es una sola copia y ocupa dos manos. La mano secundaria
muestra un símbolo de reserva, evitando repetir la imagen de la espada. El
distintivo 2M y la descripción explican el uso de ambas manos. Dos copias reales
de un objeto siguen apareciendo en dos ranuras; los recursos apilables usan
una ranura con cantidad. Equipar un escudo libera un arma de dos manos.

## Cámara y salto

El botón de cámara junto al minimapa alterna seguimiento bloqueado y órbita
libre. Clic derecho sobre ese botón selecciona la cámara libre. La elección
se guarda en ajustes. Mientras está bloqueada, WASD usa la orientación del
personaje; A/D desplazan lateralmente y S retrocede. Esto evita que el giro de
cámara y el giro del personaje formen un bucle al desplazarse.

Arrastrar con botón derecho permite mirar alrededor. Durante ese arrastre,
WASD sigue la orientación de cámara y el personaje puede adoptar una nueva
dirección; al soltar se recupera el seguimiento si permanecía bloqueado.

El modelo contiene Basic_Jump (5.93 s). El alias de gameplay utiliza el tramo
1.60–2.65 s, sincronizado con el tiempo de vuelo físico. La traslación vertical
del hueso raíz no duplica la elevación del controlador. El clip original se
conserva disponible.

## Generación de imágenes

Se utilizó la herramienta integrada ImageGen. Los archivos finales están
copiados dentro del proyecto; las texturas originales permanecen intactas.
Los pictogramas, marcos, rutas y escena se crearon como recursos SVG/Godot.

Especificaciones del conjunto de prompts (resumen de producción):

1. **Pergamino:** fondo vertical para inventario medieval; centro amplio de
   pergamino marfil con fibras y desgaste suave; marco de cuero oscuro y latón
   antiguo, nudos discretos en las esquinas; vista frontal plana, sin texto,
   botones, objetos ni ranuras. Fondo opaco.
2. **Yggdrasil:** simplificar el concepto anterior hacia un árbol del mundo
   vertical, tronco central claro, copa amplia y raíces extendidas. Ilustración
   conceptual de madera/latón grabado sobre piedra azul oscura, menos detalle,
   menos microtextura y más espacios tranquilos para superponer rutas de
   habilidades. Sin mapa geográfico, textos, símbolos de habilidad ni interfaz.
3. **Medallón:** una pieza circular aislada de latón envejecido y cuero oscuro,
   ornamentación nórdica sobria, centro vacío para iconos intercambiables,
   vista frontal plana, sin letras ni pictograma central; exterior transparente.

La variante `atlas_concept_v1.png` es un estudio anterior conservado como
referencia y no se carga en la interfaz actual.

## Validación

Pruebas: `gameplay_hud_smoke`, `player_controls_smoke`,
`hand_equipment_flow_smoke` y `player_controls_world_smoke`.
Verifican centrado y apilado de objetos, exclusión de equipo de dos manos,
zoom anclado al cursor, arrastre y ficha de rama, alineación de cámara,
sincronización del salto y control de cámara en el minimapa real.

`ui_visual_capture.tscn` permite revisar las pantallas con el renderizador real.
Guarda capturas en `res://.godot/`; ejecutar las pruebas con APPDATA aislado
evita reemplazar las preferencias del jugador.
