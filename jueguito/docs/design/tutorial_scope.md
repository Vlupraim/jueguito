# Alcance inicial del tutorial

El tutorial ocurre sobre el sector canonico `(27, 30)`. El terreno pertenece al
mundo real y sigue siendo alcanzable por otros jugadores; solamente la guia, los
marcadores y el progreso son individuales para cada personaje.

El personaje aparece sobre arena seca cerca de `(273, 7, 218)`, mirando hacia el
drakkar encallado de la costa central. El barco usa la colocacion elegida en el
workspace Terrain3D, con centro aproximado en `(273.06, 3.24, 188.78)`.

El naufragio tiene casco y bordes con hitbox, una cubierta caminable y un acceso
inclinado desde la arena. El personaje solo puede entrar o salir de la plataforma
por ese acceso; mientras esta sobre la cubierta, los bordes no permiten caer por
error. La escena tambien expone anclas para abordar y recuperar una posicion
segura sobre el barco.

## Orientacion y mapa local

La direccion aprobada de movimiento, camara e interaccion se define en
`res://docs/design/player_movement_camera_interaction.md`. La camara en tercera
persona sigue al personaje. El boton derecho permite orbitarla y orientar la
intencion frontal, la rueda controla el zoom y `F` la recentra. `WASD` mueve al
personaje con relacion a la camara, `Shift` permite correr y `Espacio` saltar.
Las orientaciones fijas y camaras cenitales se reservan para depuracion. El HUD
no muestra texto tecnico durante el juego normal.

Cada chunk tiene dos representaciones locales. El minimapa pequeno es una carta
medieval generada desde `surface_reference.png` y `height_preview.png`, con costa
suavizada, relieve y marcadores dinamicos. Al entrar al chunk se realiza ademas
un unico escaneo 3D con una camara cartografica; `Tab` reutiliza esa captura y
permite zoom, desplazamiento, salidas y leyenda. Al cruzar a otro chunk cambian
ambas representaciones. El mapa general queda reservado para una futura pantalla
de atlas o viaje y no forma parte de la vista de `Tab`.

## Objetivo de la primera version

Ensenar el bucle minimo sin introducir sistemas que aun no estan terminados.

1. **Orientacion inicial**
   - Presentar el lugar y un objetivo visible cercano.
   - Explicar movimiento con `WASD`, carrera con `Shift` y salto con `Espacio`.
   - Explicar zoom con la rueda, orbita con boton derecho y recentrado con `F`.
2. **Primera interaccion**
   - Acercarse a un objeto sencillo del mundo.
   - Seleccionarlo con clic izquierdo e interactuar en rango con `E` o clic.
   - Recibir un recurso de prueba.
3. **Inventario**
   - Abrir el panel lateral con `I`.
   - Reconocer el recurso recibido y su cantidad.
   - Cerrar el inventario con `I` o `Esc`.
4. **Menu de pausa**
   - Mostrar que `Esc` abre el menu.
   - Permitir continuar o salir al menu principal.
5. **Cierre y salida**
   - Alcanzar un hito fisico de la isla, como un muelle, fogata o portal.
   - Marcar el tutorial como completado por personaje.
   - Habilitar el flujo normal de viaje por el mundo.

## Reglas de alcance

- El tutorial no duplica ni reemplaza el terreno del sector.
- El inventario y el progreso pertenecen al personaje, no a la escena.
- NPC, indicadores y mensajes tutoriales pueden mostrarse solo al jugador que los
  necesita, aunque la isla sea compartida.
- Ningun paso del tutorial usa click-to-move ni autoaproximacion a objetivos.
- El salto no permite evitar la rampa del naufragio, los limites del sector ni
  los bloqueos de mar abierto.
- Combate, equipamiento, crafting y mercado se agregaran cuando sus sistemas base
  existan; no deben bloquear esta primera version.
