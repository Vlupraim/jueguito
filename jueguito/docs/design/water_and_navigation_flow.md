# Agua, costa y navegación

Estado: prototipo funcional inicial
Fecha: 22 de julio de 2026

## Objetivo

El agua debe ser visualmente legible, permitir vadear y nadar cerca de costa y
convertir el mar abierto en una barrera natural que se supera mediante barcos.
No se simula un fluido volumétrico: presentación, detección y reglas de gameplay
son capas separadas.

## Capas implementadas

### Presentación

- Nivel del mar estable en `Y = 2.0`.
- La malla se prolonga bajo la franja costera y el relieve Terrain3D recorta
  visualmente el borde. Esto elimina los escalones de la máscara y permite
  dibujar una costa curva esculpiendo el terreno.
- Mapa normal y mapa de altura animados en dos direcciones.
- Colores distintos para agua baja y profunda.
- El agua profunda usa un tono más oscuro y una rama de shader simplificada:
  omite espuma y detalle secundario lejos de costa. La malla visual usa una
  cuadrícula de `64 x 64` en vez de `128 x 128`.
- Espuma calculada con la profundidad real respecto del terreno y rota con la
  máscara `Foam003` para evitar una línea blanca uniforme.
- El movimiento visual de las olas no altera la colisión ni la altura lógica.

### Detección

- `OceanWater` crea un `Area3D` sobre las celdas de agua.
- El volumen lógico solo cubre 12 m bajo la superficie y usa una cuadrícula de
  colisión de `32 x 32`; mar abierto se clasifica por máscara, no por crear una
  profundidad física enorme.
- `get_water_info()` devuelve estado, profundidad de clasificación, cercanía a
  costa, `surface_locked` y `float_height`. Estas dos últimas propiedades son el
  contrato común de flotación para personajes, objetos y futuras embarcaciones.
- Un punto solo cuenta como agua si pertenece a la franja oceánica y el terreno
  está por debajo del nivel del mar. La detección y la imagen comparten borde.
- La malla y los detectores se reconstruyen al cambiar de sector.

### Personaje

El contrato general de locomocion y salto se define en
`res://docs/design/player_movement_camera_interaction.md`.

| Estado | Regla inicial |
| --- | --- |
| `dry` | Movimiento terrestre normal. |
| `wading` | Hasta 1,20 m: mantiene el fondo y reduce la velocidad al 55 %. |
| `swimming` | Más de 1,20 m: línea de agua en hombros, cabeza y brazos visibles. |
| `open_water` | Impide continuar sin embarcación y conserva la última posición segura. |

Al entrar a profundidad de natación el cuerpo queda fijado inmediatamente a la
lámina del mar, aplicando solamente su offset de flotación. No existe descenso
ni buceo: el relieve submarino clasifica costa y mar abierto, pero no constituye
un recorrido vertical. La natación utiliza `swim_idle` al detenerse y
`swim_forward` al desplazarse. Faltan resistencia, corriente de retorno,
salpicaduras y respuesta de cámara.

No se inicia un salto desde `swimming` ni `open_water`. Si una trayectoria aerea
entra al volumen logico del oceano, se resuelve el estado de agua al contacto;
el salto no permite atravesar el bloqueo de mar abierto ni salir de los limites
autoritativos del sector.

### Audio

- Loop general de oleaje.
- Capa de agua entrando y retirándose.
- Golpes de ola ocasionales con variación de tono.
- Reproducción posicional desde el centro estimado de la costa y bus
  `Ambience`.

## Fuente espacial

Cada sector reutiliza `data/terrain3d_exports/sector_X_Y/surface_reference.png`.
La máscara conserva el footprint original del export de `512 × 512`, por lo que
el océano acompaña el sector correcto sin desplazarse si una edición accidental
alcanza el exterior.

## Edición de costa

- El nivel del mar de referencia es `Y = 2.0`.
- En `terrain3d_sector_workspace.tscn`, **Height** sube o baja la playa y
  **Smooth** elimina esquinas o escalones. La arena se pinta por separado: la
  textura no determina dónde empieza el agua.
- Terreno por encima de `Y = 2.0`: seco. Terreno por debajo: queda cubierto si
  está dentro de la franja oceánica. Conviene una pendiente progresiva, no un
  muro vertical.
- La generación automática aplica un perfil continuo: fondo profundo, fondo
  somero bajo `Y = 2.0`, costa baja y playa que gana altura gradualmente hacia
  el interior. La transición usa hasta 9 píxeles de la máscara bajo el agua
  (aprox. 1,8 km) y 4 píxeles en tierra (aprox. 800 m).
- El nodo `OceanPreview` actualiza el agua poco después de terminar una
  pincelada. Sus propiedades permiten ocultarla, cambiar temporalmente el nivel
  del mar o forzar `refresh_preview` desde el Inspector.
- El rectángulo del océano se fija al footprint original del export (`512 ×
  512` con la escala actual). Las regiones auxiliares que Terrain3D cree al
  suavizar fuera del borde no pueden desplazar ni estirar la costa.
- La creación automática de regiones de Terrain3D está bloqueada en este
  proyecto. Esto aplica a altura, suavizado, materiales, color e instancias: una
  brocha puede tocar el borde visualmente, pero solo guarda datos dentro de las
  cuatro regiones del sector.
- El dock `Mapa Sectores MMO` avisa si una edición antigua ya contiene regiones
  exteriores. `Limpiar fuera de 512` respalda primero la carpeta completa del
  sector y elimina solo esas regiones auxiliares.

## Arquitectura

- Escena: `res://scenes/world/water/ocean_water.tscn`.
- Lógica: `res://scripts/world/water/ocean_water.gd`.
- Shader: `res://shaders/ocean_surface.gdshader`.
- Recursos: `res://assets/environment/water/`.
- Audio: `res://assets/audio/sfx/environment/ocean/`.

## Cinta visual del sector

- El footprint completo de `512 x 512` permanece renderizado.
- Los 48 metros exteriores de cada lado forman una cinta exclusivamente visual.
- El area jugable termina en el borde interior de esa cinta, por lo que la
  camara sigue viendo terreno aunque el personaje alcance el limite fisico.
- La cinta no precarga sectores vecinos y no debe contener NPC, recursos ni
  logica persistente.
- Solo una salida autoral registrada puede extender temporalmente el movimiento
  tres metros dentro de la cinta para activar una futura transicion de sector.
- El cambio de sector seguira descargando el terreno actual antes de presentar
  el siguiente; la cinta resuelve presentacion, no streaming.

## Siguientes iteraciones

1. Probar visualmente la orientación del mapa normal y calibrar escala de ondas.
2. Añadir salpicaduras y sonido de pasos durante el vadeo.
3. Incorporar animación de natación hacia delante y resistencia.
4. Sustituir el bloqueo seco del mar abierto por corriente y retorno a costa.
5. Crear un controlador de embarcación que pueda atravesar `open_water`.
6. Validar movimiento y posición de barcos de forma autoritativa en servidor.

La base de plataforma ya existe en el naufragio del tutorial: cubierta y rampa
se consultan como superficies caminables separadas de Terrain3D. Para navegar,
el barco reparado debera mover visual, hitboxes, superficies y anclas bajo una
misma transformacion, conservar la posicion local de cada pasajero y replicarla
desde la autoridad del servidor.
