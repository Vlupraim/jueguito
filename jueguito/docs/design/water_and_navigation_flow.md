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
- Espuma calculada con la profundidad real respecto del terreno y rota con la
  máscara `Foam003` para evitar una línea blanca uniforme.
- El movimiento visual de las olas no altera la colisión ni la altura lógica.

### Detección

- `OceanWater` crea un `Area3D` sobre las celdas de agua.
- `get_water_info()` devuelve estado, profundidad, nivel, cercanía a costa y
  clasificación de agua profunda.
- Un punto solo cuenta como agua si pertenece a la franja oceánica y el terreno
  está por debajo del nivel del mar. La detección y la imagen comparten borde.
- La malla y los detectores se reconstruyen al cambiar de sector.

### Personaje

| Estado | Regla inicial |
| --- | --- |
| `dry` | Movimiento terrestre normal. |
| `wading` | Hasta 1,20 m: mantiene el fondo y reduce la velocidad al 55 %. |
| `swimming` | Más de 1,20 m: línea de agua en hombros, cabeza y brazos visibles. |
| `open_water` | Impide continuar sin embarcación y conserva la última posición segura. |

Al entrar a profundidad de natación el cuerpo converge suavemente a la
superficie; no se teletransporta hacia arriba. La natación utiliza por ahora
`swim_idle`. Faltan una animación de avance,
resistencia, corriente de retorno, salpicaduras y respuesta de cámara.

### Audio

- Loop general de oleaje.
- Capa de agua entrando y retirándose.
- Golpes de ola ocasionales con variación de tono.
- Reproducción posicional desde el centro estimado de la costa y bus
  `Ambience`.

## Fuente espacial

Cada sector reutiliza `data/terrain3d_exports/sector_X_Y/surface_reference.png`.
La máscara se adapta a los límites de las regiones Terrain3D activas, por lo que
el océano acompaña tanto sectores importados como sectores editados.

## Edición de costa

- El nivel del mar de referencia es `Y = 2.0`.
- En `terrain3d_sector_workspace.tscn`, **Height** sube o baja la playa y
  **Smooth** elimina esquinas o escalones. La arena se pinta por separado: la
  textura no determina dónde empieza el agua.
- Terreno por encima de `Y = 2.0`: seco. Terreno por debajo: queda cubierto si
  está dentro de la franja oceánica. Conviene una pendiente progresiva, no un
  muro vertical.
- El nodo `OceanPreview` actualiza el agua poco después de terminar una
  pincelada. Sus propiedades permiten ocultarla, cambiar temporalmente el nivel
  del mar o forzar `refresh_preview` desde el Inspector.

## Arquitectura

- Escena: `res://scenes/world/water/ocean_water.tscn`.
- Lógica: `res://scripts/world/water/ocean_water.gd`.
- Shader: `res://shaders/ocean_surface.gdshader`.
- Recursos: `res://assets/environment/water/`.
- Audio: `res://assets/audio/sfx/environment/ocean/`.

## Siguientes iteraciones

1. Probar visualmente la orientación del mapa normal y calibrar escala de ondas.
2. Añadir salpicaduras y sonido de pasos durante el vadeo.
3. Incorporar animación de natación hacia delante y resistencia.
4. Sustituir el bloqueo seco del mar abierto por corriente y retorno a costa.
5. Crear un controlador de embarcación que pueda atravesar `open_water`.
6. Validar movimiento y posición de barcos de forma autoritativa en servidor.
