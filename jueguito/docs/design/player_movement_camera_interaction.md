# Movimiento, cámara e interacción del jugador

Estado: control local implementado; autoridad de red y reasignación pendientes
Fecha de decisión: 17 de agosto de 2026
Actualización de implementación: 12 de octubre de 2026

## Implementación local actual

El mundo Terrain3D usa WASD relativo a cámara, carrera con Shift y salto con
Espacio. El clic derecho mantenido captura el puntero y permite orbitar; al
soltarlo vuelve el cursor. La rueda aproxima desde tercera persona hasta primera
persona y F centra detrás del personaje. SpringArm3D respeta las capas físicas
de terreno, recursos y plataformas, excluyendo al propio personaje. La geometría
sin collider necesita autoría de colisión para bloquear cámara y movimiento.

Opciones > Controles permite ajustar sensibilidad, velocidad de zoom,
inclinación inicial e inversión vertical. Las preferencias se guardan; el formato
3 migra la inclinación del encuadre táctico anterior a -15 grados.

La estamina tiene 100 puntos: correr consume 28/s y recupera 22/s después de
0,8 s sin correr. Al agotarse se camina hasta recuperar al menos el 25 %. La barra
del HUD refleja el estado real. Los valores son provisionales y configurables en
el controlador. El salto tiene gravedad, control aéreo limitado y usa la
animación de salto disponible; no permite doble salto ni iniciar saltos nadando.

Inventario, mapas, pausa y edición del HUD bloquean los controles. Moverse o
saltar cancela canalizaciones. Clic izquierdo o E interactúan en rango, con un
aviso cuando el objetivo está lejos. No generan aproximación automática.

La integración de red sigue siendo el mock del prototipo: este cambio implementa
el control local, no predicción ni reconciliación con un servidor persistente.
Las reglas de rampa/cubierta dependen de superficies con metadatos; el GLB del
naufragio que está colocado actualmente no incluye las superficies requeridas
por la prueba histórica de abordaje.

Pruebas: player_controls_smoke, player_controls_world_smoke,
gameplay_hud_smoke, player_water_flow_smoke y sector_boundary_smoke.

## Decisión

La experiencia jugable adopta locomoción directa en tercera persona, inspirada
en los MMO de acción. `WASD` y el salto reemplazan definitivamente el
click-to-move como contrato de movimiento normal.

La referencia externa sirve para comunicar la intención, pero este documento es
la fuente canónica. Si una referencia y estas reglas difieren, prevalecen estas
reglas.

## Objetivos

- Dar control inmediato y continuo sobre el personaje.
- Alinear exploración, combate, recolección y navegación bajo un único modelo.
- Hacer que cámara, orientación corporal y dirección de movimiento sean
  predecibles.
- Permitir salto sin convertirlo en una forma de evadir límites, colisiones o
  accesos autorales.
- Mantener separadas las cámaras de gameplay y las herramientas de depuración.

## Contrato de entrada objetivo

| Entrada | Comportamiento |
| --- | --- |
| `W` / `A` / `S` / `D` | Movimiento sobre el plano horizontal, relativo a la orientación de la cámara. |
| `Shift` | Correr mientras existe entrada de movimiento. |
| `Espacio` | Saltar desde una superficie válida. No existe doble salto. |
| Botón derecho + mouse | Orbitar la cámara y orientar la intención frontal del personaje. |
| Rueda del mouse | Acercar o alejar la cámara dentro de límites seguros. |
| Clic izquierdo | Seleccionar un objetivo o activar una interacción válida bajo el cursor. |
| `E` | Interactuar con el objetivo enfocado o seleccionado cuando está en rango. |
| `F` | Recentrar la cámara detrás del personaje. |
| `Esc` | Retroceder en UI o abrir el menú de pausa. |

Las acciones deben existir en el `InputMap` con nombres semánticos y ser
reasignables. El código de gameplay no debe depender directamente de teclas
físicas una vez terminada la migración.

## Movimiento y orientación

- La cámara define los ejes horizontales de movimiento; su inclinación vertical
  no altera la velocidad ni hace volar al personaje.
- El personaje gira suavemente hacia la dirección de movimiento. Mientras el
  botón derecho controla la cámara, la orientación frontal puede seguir la
  dirección de cámara necesaria para apuntar o combatir.
- Soltar `WASD` detiene la intención de locomoción. No queda un destino remoto
  activo y el personaje no continúa caminando por su cuenta.
- El click-to-move se elimina del gameplay normal. Puede existir en herramientas
  internas o accesibilidad solo si se documenta como un modo explícito y no
  altera el contrato predeterminado.
- Las cámaras libre, ortográfica y cenital son herramientas de edición o debug;
  no forman parte de la experiencia jugable publicada.

## Cámara de gameplay

- Usa perspectiva en tercera persona, seguimiento del personaje y prevención de
  atravesar geometría mediante `SpringArm3D` o una solución equivalente.
- Permite órbita continua, zoom hasta primera persona y recentrado detrás del personaje.
- El encuadre debe conservar legibilidad del terreno próximo, objetivos e
  interacciones sin ofrecer información indebida a través de muros.
- Abrir inventario, mapa, pausa u otra UI que capture el puntero bloquea
  movimiento, cámara e interacción local según corresponda.
- Sensibilidad, inversión vertical, velocidad de zoom y reducción de movimiento
  pertenecen a las opciones del cliente.

## Salto

- Solo comienza al estar apoyado sobre una superficie caminable y cuando el
  estado actual lo permite.
- Durante el salto se conserva control aéreo limitado, sujeto a calibración; no
  se permite cambiar instantáneamente de dirección a velocidad completa.
- La gravedad, velocidad vertical, tiempo en el aire y aterrizaje forman parte
  del estado de locomoción y de la validación autoritativa.
- Saltar cancela canalizaciones e interacciones que exijan inmovilidad.
- El salto no autoriza cruzar el límite del sector, abordar por un costado,
  atravesar bloqueos de mar abierto ni omitir una rampa o salida registrada.
- Los obstáculos críticos deben diseñarse y probarse considerando altura y
  distancia máximas de salto, cápsula del personaje y pendientes.

## Interacción

- Seleccionar o hacer clic sobre un objeto lejano nunca genera movimiento
  automático.
- Una interacción solo comienza dentro de su alcance válido. Fuera de rango, la
  UI comunica que el jugador debe acercarse manualmente.
- `E` ofrece una alternativa estable al clic para objetivos enfocados; el clic
  izquierdo puede iniciar la misma acción cuando el objeto está en rango.
- Iniciar movimiento, saltar, perder el rango, cerrar el control jugable o
  cambiar a un estado incompatible cancela una acción canalizada.
- Servidor y cliente validan la interacción con la posición oficial; selección y
  resaltado visual no conceden alcance ni permisos.

## Agua, plataformas y límites

- `WASD` conserva las reglas de velocidad de tierra, vadeo y natación.
- No se puede saltar al nadar ni en mar abierto. Entrar al agua durante un salto
  resuelve el estado correspondiente al tocar su volumen lógico.
- Cubiertas, rampas, muelles y embarcaciones declaran superficies y transiciones
  válidas. La trayectoria aérea no anula esas reglas.
- El borde jugable y la cinta visual del sector siguen siendo límites
  autoritativos aunque la cámara permita mirar más allá.

## Autoridad de red

El cliente envía intención de entrada y predice una respuesta inmediata. El
servidor conserva posición y velocidad oficiales, valida velocidad horizontal,
estado apoyado, impulso de salto, gravedad, superficies, agua y límites, y
corrige divergencias. No se envía una posición elegida por clic como verdad del
movimiento normal.

## Migración desde el prototipo

El control local del mundo Terrain3D ya reemplaza click-to-move y
autoaproximación. El proveedor de altura sigue ayudando al movimiento terrestre;
el estado aéreo conserva velocidad vertical y gravedad hasta aterrizar. Las
herramientas antiguas pueden conservar cámaras de depuración. La migración
autoritaria de mensajes de red y la reasignación desde UI siguen pendientes.

Orden recomendado:

1. Crear acciones semánticas en `InputMap` y locomoción `WASD` relativa a cámara.
2. Sustituir destino remoto y autoaproximación por selección e interacción en
   rango.
3. Consolidar la cámara de gameplay y retirar presets jugables incompatibles.
4. Introducir estado apoyado/aéreo, salto, gravedad y aterrizaje también en el
   terreno guiado por generador.
5. Validar agua, plataformas, límites y cancelación de acciones.
6. Migrar mensajes de red desde destino aprobado hacia intención, velocidad y
   reconciliación autoritativa.
7. Añadir opciones reasignables, tutorial y pruebas de regresión.

## Criterios de aceptación

- El jugador recorre el tutorial usando `WASD`, `Shift` y `Espacio`, sin
  click-to-move.
- Movimiento y cámara se bloquean correctamente con UI modal.
- Un clic lejano no desplaza al personaje.
- No es posible saltar al mar abierto, fuera del sector ni a la cubierta del
  naufragio evitando su acceso válido.
- Las canalizaciones se cancelan al moverse o saltar.
- La simulación autoritativa rechaza velocidades o saltos incompatibles con el
  estado oficial.
- Teclado y mando usan acciones semánticas, con foco de UI independiente.

## Trazabilidad

- Tutorial: `res://docs/design/tutorial_scope.md`.
- Agua y navegación: `res://docs/design/water_and_navigation_flow.md`.
- Menús, opciones y bloqueo de input:
  `res://docs/design/menu_flow_and_settings.md`.
- Interacción con árboles: `res://docs/technical/harvestable_trees.md`.
- Red y persistencia:
  `res://docs/technical/authoritative_networking_and_persistence.md`.
- Implementación actual:
  `res://scripts/characters/player/player_controller.gd` y
  `res://scripts/terrain3d_walk_preview.gd`.
