# Atmósfera costera v1

## Composición

El horizonte combina un cielo con nubes, bruma por distancia y continuidad
visual del océano fuera del sector cargado. La franja rosada anterior provenía
del cielo inferior descubierto al terminar la malla de agua.

El océano distante prolonga solamente los tramos del borde clasificados como
agua en la máscara del sector. Es una malla de decorado sin colisión, audio ni
agua jugable adicional. La máscara, el vadeo y el bloqueo de mar abierto se
mantienen dentro de los límites originales. La continuidad de tierras lejanas
deberá proceder de representaciones simplificadas de los sectores vecinos.

La bruma general comienza a 160 unidades y alcanza su intensidad máxima a 2600.
El material del mar añade un velo suave entre 140 y 1050 unidades, con fuerza
máxima 0.38, atenuando color/reflejos hacia el color de la atmósfera. Conserva
la niebla del Environment. Escribir FOG en el shader reemplazaría esa niebla,
por lo que este velo utiliza albedo atenuado y emisión en su lugar.

## Nubes y viento

Las nubes se dibujan en una capa horizontal aparente, con una textura de ruido
suave de 1024 × 1024. El shader utiliza la pasada a media resolución de la
pantalla; no muestra las nubes desde el mapa de iluminación de 256 px que
producía bordes pixelados. La mezcla final filtra la capa y mantiene el cielo
y el disco solar a resolución de pantalla. El mapa de iluminación solo calcula
el gradiente y el sol, sin volver a calcular las nubes.

Se conserva una franja libre de nubes junto al horizonte. La proyección usa el
ángulo real sobre esa franja; no congela su denominador cerca del horizonte,
que era la causa de las manchas estiradas hacia abajo.

El recurso WeatherWind define dirección horizontal y velocidad en metros por
segundo. Las nubes se desplazan en esa dirección, despacio, a una altura visual
de 900 unidades. Cambiar la dirección o velocidad del recurso actualiza el
cielo; velocidad cero detiene la deriva.

El viento todavía no aplica fuerzas, controla velas, cambia el oleaje ni
simula clima territorial. Su método get_velocity() entrega una velocidad
mundial común que podrá consultar un controlador de navegación más adelante.
La niebla volumétrica permanece desactivada en este perfil.

## Recursos para editar en Godot

- `res://resources/environment/coastal_daylight.tres`: cielo, textura de nubes,
  cobertura, escala, colores y niebla general.
- `res://resources/environment/coastal_wind.tres`: dirección y velocidad.
- `res://scripts/world/environment/weather_wind.gd`: datos y velocidad mundial.
- `res://shaders/coastal_sky.gdshader`: capas y desplazamiento de nubes.
- `res://scenes/world/water/ocean_water.tscn`: bruma marina en el material.
- `res://scripts/world/water/ocean_water.gd`: extensión visual del mar.

El preview caminable carga el Environment y expone Weather Wind en su
Inspector. El control existente de niebla activa/desactiva tanto la niebla
general como el velo marino.

## Validación

`coastal_atmosphere_smoke.tscn` comprueba que la extensión permanece fuera del
sector, no amplía el agua jugable, conserva los colliders y responde al control
de niebla. También comprueba que el cielo recibe la velocidad del recurso.
Con renderizador gráfico captura el horizonte a dos inclinaciones de cámara
y compara una zona del cielo antes/después para confirmar movimiento.

Validado con Godot 4.7 Forward+ y D3D12 en RTX 3050. Las pruebas de agua y
movimiento acuático siguen pasando. El coste en otros equipos requerirá
medición; esta versión no incluye nubes volumétricas.

Referencias técnicas:

- [Sky shaders y pasadas a resolución reducida](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/sky_shader.html).
- [Environment y controles de niebla](https://docs.godotengine.org/en/stable/classes/class_environment.html).
- [Shader espacial: salida FOG](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html).
