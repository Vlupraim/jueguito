# Movimiento, cámara e interacción del jugador

Estado: dirección aprobada, pendiente de implementación completa
Fecha de decisión: 17 de agosto de 2026

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
- Permite órbita continua, zoom limitado y recentrado suave.
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

El prototipo todavía contiene click-to-move, autoaproximación a interactuables y
ajuste directo a la altura del generador. Hasta completar la migración, los
documentos operativos pueden describir esos controles únicamente si los marcan
como estado actual.

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
