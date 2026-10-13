# Comprobación de costa cooperativa · 2026-10-12

## Versión 0.2: bruma, locomoción, menú online y PvP

Se probaron el cliente y servidor exportados de `dist/costa-bruma-pvp/` con
dos procesos cliente y un servidor independiente en UDP 17787. Datos y ajustes
de prueba aislados. Resultado: `COOP_COMBAT_MULTIPROCESS_PASS` y
`COOP_MULTIPROCESS_PASS`.

- PvP desactivado impide daño; ambos activados permiten un único golpe de espada
  de 18. Solicitudes repetidas se rechazan durante el tiempo de espera.
- El menú online bloquea los controles y continúa la gravedad. El jugador recibe
  daño con el menú abierto. La animación de ataque se replica al observador.
- Alejarse impide golpes; no se puede desactivar PvP durante combate.
- A cero vida se restaura a 100, se desactiva PvP, se actualiza el HUD y se
  conservan los objetos.
- La tala compartida concede cuatro maderas a un solo jugador. Se conserva
  inventario y agotamiento del árbol después de reiniciar el servidor.
- Se mantienen rechazo de clave errónea, corrección de teletransporte, movimiento,
  salto, equipo remoto y retirada de jugadores desconectados.
- Se retiró el inventario de las actualizaciones periódicas: se entrega a su dueño
  al entrar y al cambiar. Las actualizaciones de actores se dividen por tamaño
  (900 bytes de datos) y se aplican solo cuando llega el conjunto completo. Se
  comprobó composición fuera de orden y rechazo de estados anteriores.

`COAST_QUALITY_SMOKE PASS` se ejecutó con GPU RTX 3050, Forward+/D3D12. Verifica
perfiles de nitidez, bruma y distancia, duración de estamina, velocidad proporcional,
reproducción según recorrido, acciones sin heredar velocidad de locomoción y
rechazo de golpes a través de una pared física de prueba. Capturas en
`.godot/network_validation/fog-{coast,inland,near-ship,border}.png`.

`PLAYER_CONTROLS_SMOKE_OK` y `PLAYER_CONTROLS_WORLD_SMOKE_OK` verificaron WASD,
salto, cámara, menús y HUD. El mismo recorrido caminando de 35 ticks pasó de
2.239 m a 1.512 m; el salto conservó una altura de 1.225 m sobre el suelo.

El binario con metadatos de aplicación modificados fue bloqueado por Control de
aplicaciones de Windows. La distribución usa el ejecutable oficial de Godot 4.7
sin modificar, junto con el PCK actualizado. Ambos binarios tienen el mismo SHA256
que `windows_release_x86_64.exe`; los presets desactivan `modify_resources`.
Las pruebas indicadas arriba usaron ese ejecutable final. No se cambiaron políticas
de Windows. La versión del juego se identifica en `manifest.json`.

Las colisiones exportadas actuales son los once troncos. La pared sintética valida
la ruta de colisión del servidor para futuras paredes; barco y parte del decorado
requieren todavía colisiones. La vida no persiste al reconectar y el movimiento
continúa con predicción del cliente y comprobaciones del servidor. Esta versión
es una prueba privada; los pasos entre sectores y PvP competitivo siguen pendientes.
No se verificaron rendimiento en otro PC ni una conexión externa por Internet.

Los registros aún incluyen la advertencia de interpolación del Terrain3D anterior
y algunos recursos pendientes al cerrar procesos de prueba. No hubo errores de
script ni fallos de las comprobaciones anteriores en la ejecución final.

Godot 4.7 estable. Se ejecutaron tres procesos separados: servidor dedicado y
dos clientes Windows exportados, con UDP local 17781 y datos de prueba aislados.

Resultado: `COOP_MULTIPROCESS_PASS`; Alice, Bob, clave errónea y reconexión dieron
`PASS`. La prueba verificó:

- Entrada simultánea y aparición del personaje remoto con movimiento, salto y hacha.
- Rechazo de un teletransporte de 60 metros.
- Terreno del sector 27,30 y sus 25 texturas; mar con 1.769 celdas y 20 colliders.
- Tala nativa temporizada: cuatro maderas para Alice, cero para Bob al competir.
- Tocón compartido y restauración del árbol si el servidor rechaza la predicción.
- Retirada del personaje al desconectarse y rechazo de una clave equivocada.
- Inventario y árbol agotado recuperados tras cerrar y reiniciar el servidor.

El lanzador `IniciarServidor.ps1`, usado por el BAT, también inició correctamente
el servidor desde su carpeta con `server.cfg` y UDP 7777. La prueba de salida del
modo local dio `GAMEPLAY_EXIT_SMOKE_OK`. Los procesos de prueba se cerraron.

Se corrigieron tres problemas que solo se observaban al exportar: lectura de
imágenes originales en lugar de recursos importados, exploración de directorios
físicos en lugar del PCK y omisión de las referencias del mar/minimapa.

El control de aplicaciones de este Windows bloqueó el envoltorio de consola
opcional generado por Godot. Se sustituyó por un lanzador PowerShell que ejecuta
el binario principal y muestra sus logs; ese arranque fue comprobado. No se
cambió la política de Windows.

No se ha validado conexión desde Internet ni rendimiento en otro PC. Las pruebas
de red fueron locales; se conserva la advertencia de deprecación de la versión
actual de Terrain3D sobre `instance_reset_physics_interpolation`. La captura
automática de la ventana oculta no se completó y no se usa como evidencia visual.

Los ZIP distribuidos incluyen los ejecutables, PCK, DLL, guía y manifiestos SHA256.
El servidor contiene su clave aleatoria local; no se publica en Git. Los binarios
y datos de prueba permanecen fuera del repositorio versionado.
