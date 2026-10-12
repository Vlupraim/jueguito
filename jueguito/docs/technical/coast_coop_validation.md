# Comprobación de costa cooperativa · 2026-10-12

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
