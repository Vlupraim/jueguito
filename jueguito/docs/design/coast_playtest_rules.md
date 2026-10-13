# Reglas de la costa y siguientes pruebas

## Versión 0.2

- Escape consume los controles. Online siguen gravedad, jugadores, estamina y
  daño. Offline conserva la pausa. Opciones y edición del HUD tampoco protegen online.
- Caminar: 2.6 m/s. Correr: caminar × 2.36, actualmente 6.136 m/s. La reproducción
  sigue el desplazamiento real, incluyendo frenadas y colisiones. Los pies de
  Strong Man dieron aproximadamente 1.38 m/s en `walk` y 4.17 m/s en `run` a
  reproducción 1.0; se usan referencias editables de 1.4 y 4.2 m/s.
- Estamina: 100, consumo de carrera 7/s frente a 28/s. Dura unos 14.3 segundos,
  cuatro veces lo anterior (+300%). Recuperación 22/s, espera de 0.8 s y umbral
  de 25 puntos para volver a correr después de agotarla.
- PvP desactivado al conectar. Ambos deben activarlo bajo el indicador de conexión.
  Clic izquierdo sobre otro jugador inicia un golpe a corta distancia.
- Manos: 6 de daño; hacha: 12; espada: 18. Alcance 2.8 m, diferencia vertical
  máxima 1.5 m, cono frontal de 120°, preparación de 0.25 s y pausa de 0.95 s entre
  golpes. El arco aún no tiene proyectiles.
- El servidor comprueba consentimiento, posición aceptada, orientación, equipo,
  tiempo y obstáculos con colisiones existentes. Comprueba de nuevo al impactar:
  alejarse durante la preparación permite esquivarlo. La geometría sólida se
  exporta como formas físicas sin gráficos. Los árboles agotados dejan de bloquear
  golpes; todavía falta revisar colisiones del barco y parte del decorado.
- PvP solo se puede desactivar después de ocho segundos sin combatir. A cero
  vida se reaparece con 100, PvP desactivado y cinco segundos de protección.
  Se conservan los objetos.
- Bruma ambiental entre 55 y 360 m. La bruma fronteriza comienza aproximadamente
  a 85 m del borde visual y se espesa hacia fuera; cubre terreno y mar. El área
  caminable termina 48 m antes del borde visual y el servidor lo comprueba.
- `Opciones → Vídeo → Texturas y detalle del entorno`: Bajo/Medio/Alto cambia
  nitidez, relieve superficial, césped, decorado y detalle de bruma. Medio es el
  valor inicial. F4 no puede desactivar la niebla online.

## Prioridades propuestas

| Orden | Mejora | Qué probar |
| --- | --- | --- |
| 1 | Pasos entre regiones | Camino reconocible, carga cubierta por bruma, llegada equivalente y recuperación si falla. |
| 2 | Sensación de movimiento | Ritmo de pasos, pendientes, colisiones del barco y rocas, ajuste de pies al suelo, margen de salto después del borde y salto solicitado antes de aterrizar. |
| 3 | Lectura del combate | Objetivo marcado, aviso de alcance, reacción y sonido de impacto, momento de daño alineado al contacto del arma. |
| 4 | Reglas de desconexión y derrota | Persistir combate al reconectar; definir zonas seguras, regeneración de vida y consecuencias antes de añadir pérdidas de objetos. |
| 5 | Inventario y recolección | Arrastrar equipo, dividir pilas, recoger objetos y confirmar las transferencias en el servidor. |
| 6 | Orientación y tutorial | Señales en caminos, mensajes cortos para salto, carrera, tala y PvP; retorno seguro al atascarse. |
| 7 | Audio | Pisadas según suelo, mar, viento, bosque y avisos de interacción. |
| 8 | Calidad por equipo | Medir tiempo por frame y memoria en un PC antiguo; separar sombras, césped y resolución si hace falta. |
| 9 | Conexión | Ping, reconexión y guardado comprobado al cerrar el servidor. |

La bruma es la base visual de los pasos. Esta versión online comparte solo la
Costa del Naufragio. Para cruzar, el servidor deberá asignar un sector a cada
jugador y enviar solo los actores correspondientes. Los pasos serán datos
editables: ID, lado, ancho, destino y llegada; los demás bordes permanecerán cerrados.

Transición propuesta: acercarse prepara la carga; entrar espesa la bruma;
el servidor confirma destino y llegada; se coloca al jugador cuando el suelo está
listo y vuelve la visibilidad. Si tarda, se muestra una indicación. Si falla,
se conserva el sector anterior y se recuperan los controles.

El perfil actual usa el nombre dentro de una partida privada. Vida y PvP son de
sesión: reconectar restaura vida y desactiva PvP. Antes de PvP competitivo hay que
resolver identidad, combate persistente y movimiento simulado en el servidor.
