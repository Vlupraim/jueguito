# Auditoría general: experiencia, arte, personajes, cartografía y agua

Fecha: 13 de septiembre de 2026. Primera auditoría transversal del prototipo local.

## Alcance y evidencia

Se revisaron el README, secciones de visión y prioridades del GDD v0.8, los documentos de UI, mapas, movimiento, tutorial, maestrías, ocupaciones, personajes, entorno y agua; además de los controladores y recursos que implementan esos recorridos. Se inspeccionaron capturas existentes de portada, creador, HUD e inventario y se ejecutó Godot 4.7 con render D3D12 para obtener capturas nuevas del sector inicial, mapa regional y atlas.

Se ejecutó Blender 5.2 mediante Python y se inspeccionó la estructura del GLB Strongman. Se muestreó la concordancia entre la fuente cartográfica y la clasificación de agua del terreno cargado. Las evidencias y scripts reproducibles están en `tmp/audit_20260913/`.

No es una certificación de todos los sectores, rendimiento multijugador o calidad de todas las animaciones. No hubo una sesión prolongada de juego manual ni medición GPU aislada. Los juicios visuales son una evaluación artística; las cifras indicadas provienen de inspección o ejecución. No se modificaron los sistemas del juego, el terreno ni sus assets; se añadieron esta auditoría y sus instrumentos temporales.

## Veredicto

El proyecto tiene una fantasía identificable —vidas y oficios conectados mediante rutas, información, riesgo y poder reversible—, pero la implementación todavía comunica herramientas y sistemas en construcción. El desfase entre promesa y experiencia inmediata es mayor que la falta de modelos.

El atlas es una buena referencia de identidad. El creador, la playa y la interfaz tienen diferencias de acabado que impiden sentirlos como partes del mismo mundo. Generar muchos assets ahora multiplicaría ese problema si no se define primero una muestra pequeña del acabado final.

El objetivo próximo debe ser un recorrido corto, cómodo y coherente: aparecer, reconocer el entorno, moverse, interactuar, recoger algo útil, consultar el inventario y llegar a un destino. Después, una ruta de producción y entrega con una decisión de riesgo que pruebe la singularidad del diseño territorial.

## Hallazgos priorizados

| Prioridad | Hallazgo y evidencia | Implicación | Acción propuesta |
| --- | --- | --- | --- |
| P0 | `player_controller.gd:105` sigue adquiriendo destinos con clic derecho. El contrato del 17 de agosto prescribe WASD, órbita derecha y salto. | Se está evaluando el arte desde una experiencia de control distinta a la aprobada. | Completar primero locomoción, cámara, interacción y bloqueo de entradas por UI. |
| P0 | El terreno carga ediciones `.res`; la carta local lee `surface_reference.png` y `height_preview.png` del export original. | Una costa esculpida no queda representada fielmente en el mapa. | Derivar cartografía del terreno final y del agua definida para ese sector; versionar e invalidar sus cachés. |
| P0 | Una muestra de 4.096 posiciones del sector inicial encontró 250 discrepancias entre la clasificación de agua y su fuente cartográfica. | La divergencia es comprobable y puede inducir decisiones incorrectas de navegación. | Corregir la fuente compartida antes de embellecer el minimapa. |
| P1 | La captura actual muestra al personaje pequeño sobre una gran extensión de arena repetitiva; el barco queda parcialmente fuera del encuadre. | Falta jerarquía espacial en la primera impresión. | Ajustar cámara y composición; acercar los primeros hitos y usar caminos, rocas y vegetación para orientar. |
| P1 | El minimapa usa todo el sector, zoom 1–1,6 y centro UV fijo en 0,5. | Funciona como carta regional reducida; distingue mal los destinos próximos. | Ventana centrada en el jugador, alcance local útil y marcadores de tamaño constante. |
| P1 | Strongman tiene 150.134 triángulos fuente, un material y ninguna forma de deformación facial. | Su complejidad no está alineada con el objetivo low poly y no ofrece personalización facial preparada. | Probar reducción/retopología, materiales y LOD con animaciones antes de producir más cuerpos. |
| P1 | El selector registra un cuerpo y solamente «Sin cabello», pero expone selector y color de cabello. | Ofrece una elección sin resultado visible. | Incorporar piezas reales; mientras tanto, ocultar o desactivar opciones sin efecto. |
| P1 | HUD pequeño y oscuro; inventario con varios bordes anidados, equipo inactivo y texto secundario pequeño en las capturas existentes. | Hay ornamentación y superficie destinadas a contenido que aún no ayuda a jugar. | Simplificar jerarquía, revisar escala y probar sobre fondos reales. |
| P1 | `NetworkManager` ejecuta `ServerMock`; cuentas en memoria y validación de movimiento provisional. | El prototipo no demuestra aún persistencia ni autoridad MMO. | Validar un pequeño circuito persistente antes de expandir economía/política. |
| P1 | `MapDataManager` genera abundancias y algunos contadores aleatoriamente. | El mapa aparenta informar sobre recursos/riesgo que todavía son datos de prototipo. | Etiquetar o retirar datos ficticios y conectar fuentes verificables. |
| P2 | Documentación describe minimapa circular, rombo, captura 3D y carta ilustrada; tutorial aparece como privado y compartido en documentos distintos. | Las iteraciones pueden implementar contratos incompatibles. | Consolidar decisiones vigentes y marcar claramente los documentos históricos. |

P0 significa requisito para evaluar la experiencia propuesta, no una emergencia de producción.

## Arte y comodidad

Conservaría los colores apagados, el carácter cartográfico y el latón discreto del atlas. Reduciría la frecuencia de detalle de materiales y marcos. En el atlas, el relieve es atractivo, pero su textura continua necesita zonas de descanso y una jerarquía de nombres, rutas y destinos.

La portada existente usa formas angulares; el fondo del creador contiene vegetación y piedra mucho más detalladas; el cuerpo tiene un acabado claro y relativamente plano; la playa muestra texturas repetidas a gran escala. Cada pieza puede resultar aceptable por separado, pero juntas no establecen una regla de estilización compartida.

Low poly no significa únicamente pocos triángulos: importa la silueta, proporciones, paleta, materiales, luz y animación. Para este juego propondría anatomía simplificada, ropa con volúmenes legibles, materiales mates, contraste controlado y vegetación agrupada que deje espacio a rutas y objetivos.

La inmersión requiere que el mundo responda de manera comprensible: pies apoyados, herramientas que alcanzan su objetivo, transiciones de agua legibles, entradas visibles y acciones con respuesta. La música puede esperar; sonidos funcionales de pasos, impacto, agua e interacción deberán acompañar estas pruebas, sin decidir aquí la dirección musical del usuario.

El arte del menú debería prometer un acabado que pueda reproducirse dentro de Godot. Una escena pequeña bien compuesta serviría tanto como prueba visual del juego como fuente de fondos coherentes.

## Personajes y personalización limitada

Es viable ofrecer un cuerpo masculino y uno femenino, cabello intercambiable, paletas de piel/cabello/iris y unas pocas variantes de rostro. No hace falta un editor de proporciones libre.

El soporte actual ya guarda `hair_path` y `hair_color`, y contiene anclaje de cabello en selector y mundo. Faltan los assets, la personalización de ojos y su validación completa.

Propuesta inicial, sujeta a aprobación artística: dos cuerpos, tres peinados por ajuste de cabeza, tres variantes de rostro y una paleta limitada de colores. Cambiar color de iris es más sencillo que cambiar la forma del ojo: esta última requiere variantes de cabeza o deformaciones preparadas. Para el primer piloto preferiría cabezas discretas; las deformaciones pueden añadirse si aportan diferencias apreciables a la distancia real de cámara.

La decisión técnica decisiva es un esqueleto maestro con pose de reposo y anclajes estables. Dos cuerpos pueden usarlo, pero deben vincularse correctamente y probarse: compartir nombres de huesos no garantiza compatibilidad. La documentación actual conserva rigs independientes por personaje, con buenas razones; pasar a un maestro sería una migración explícita. Hasta entonces, cada GLB debe conservar sus propias animaciones preparadas en Blender.

Cabellos cortos pueden seguir el hueso de la cabeza; piezas largas pueden necesitar pesos/huesos y pruebas de clipping. Ropa ajustada requiere adaptación a los cuerpos; las piezas rígidas usan anclajes. Guardar identificadores estables de apariencia permite reconstruirla en selector, mundo y otros clientes sin guardar una malla distinta por combinación.

Strongman: 30,29 MiB, 80.507 vértices declarados, 150.134 triángulos fuente, una primitiva/material, un skin de 24 articulaciones y 20 animaciones. No tiene morph targets. Esto no mide el LOD que Godot acaba dibujando ni demuestra por sí solo un problema de FPS. Sí justifica revisar su coste y estructura antes de adoptarlo como base definitiva para muchos jugadores.

## Agua: diagnóstico y corrección propuesta

Dividir el mundo en sectores es una decisión defendible. Debe conservarse su herramienta de autoría. El problema encontrado es la separación entre datos editados y representaciones derivadas.

Actualmente `OceanWater` coloca la superficie en Y=2. Las olas desplazan visualmente los vértices; la flotación lógica permanece estable. La profundidad del terreno determina vadeo/natación, dentro de una zona oceánica que procede de la máscara original ampliada. No hay simulación volumétrica. Los lagos a otra altura necesitarían cuerpos de agua adicionales con límites y nivel propios; no deberían aparecer automáticamente en cualquier depresión del terreno.

En cambio, `_load_local_minimap_texture()` usa las imágenes históricas del export y las suaviza. El mapa regional activo reutiliza esa carta. La presencia de `sector_map_3d_renderer.gd` y referencias a capturas en documentación no significa que la ruta actual esté mostrando un escaneo fiel del terreno editado.

La prueba del sector `(27,30)` obtuvo:

| Medida | Resultado | Límite de interpretación |
| --- | --- | --- |
| Posiciones muestreadas | 4.096 | Cuadrícula 64×64, centros de celda. |
| Fuente marca agua, lógica actual marca seco | 250, aproximadamente 6,1% del muestreo total | Comparación con la fuente original antes del suavizado artístico; no porcentaje exacto de píxeles incorrectos del minimapa. |
| Fuente marca seco, lógica actual marca agua | 0 | Solo el sector y estado inspeccionados. |
| Malla de agua | 1.769 celdas / 3.538 triángulos | No mide coste de transparencia ni cobertura en pantalla. |
| Volúmenes de detección | 20 | La simulación del personaje consulta además altura y máscara. |
| Reconstrucción completa con recursos ya cargados | 382,894 ms | Una muestra local; no promedio, FPS ni perfil GPU. |
| Rectángulo runtime | 512×512 unidades | El documento macro y metadata hablan de 5 km por sector; no debe asumirse equivalencia métrica actual. |

La reconstrucción ocurre al configurar el sector, no en cada movimiento del jugador. En el editor se programa después de una pincelada, con una espera de 350 ms por defecto. Una reconstrucción síncrona de unos 383 ms puede contribuir a pausas al actualizar el preview; no prueba que sea la causa de todos los tirones al recorrer el mundo. Para medir estos últimos hace falta perfilar CPU, GPU, terreno, personajes y agua con cámara/ruta controladas.

Corrección en orden:

1. Definir por sector el rectángulo y transformación espacial, revisión del terreno y cuerpos de agua (identidad, límite y altura). Resolver la escala macro/runtime sin reescalar silenciosamente el terreno existente.
2. Al guardar/publicar una edición, derivar una máscara cartográfica de la altura final y de los cuerpos de agua autorizados. Conservar la intención oceánica: una depresión interior no implica conexión con el mar.
3. Usar esos datos en detección y cartas locales, con criterios explícitos de costa visual y umbral de entrada del jugador. El atlas conserva su estilo y generaliza esta información por escala.
4. Generar y guardar las cartas fuera del recorrido normal; cachearlas por revisión, no únicamente por coordenada. Una edición debe invalidar la carta correspondiente.
5. Para el preview de autoría, reutilizar las máscaras que no cambiaron y limitar la actualización al área afectada. Separar generación costosa de la presentación del frame. No acceder a objetos del motor desde hilos sin verificar que la API lo permita.
6. Mantener un nivel lógico común para el mismo mar y coordenadas coherentes de ondas entre sectores. Los lagos aislados pueden tener otros niveles. Validar las uniones cuando existan vecinos simultáneamente visibles.

Criterios de aceptación: una bahía esculpida conserva forma en mundo/minimapa/mapa; un terreno elevado sale del agua y desaparece como agua en la carta; un hueco interior no se inunda sin cuerpo de agua; cambiar zoom no reconstruye océano ni terreno; el jugador cruza seco/vadeo/natación de forma predecible; las cachés se actualizan tras una edición y sobreviven a recarga sin usar imágenes viejas.

## Meshy, Blender y Godot

Blender está instalado y se ejecutó con Python desde esta sesión. Es posible automatizar inspección, materiales, transformaciones, preparación de variantes, exports y parte del trabajo de rigging, verificando resultados visualmente. El buen acabado y las deformaciones no se garantizan por ejecutar un script.

No hay conector Meshy activo en esta sesión ni se accedió a su cuenta. Las rutas posibles son su web mediante un navegador conectado o su API autenticada. Antes de generar hay que verificar acceso y saldo del plan. No se usaron créditos ni se solicitaron contraseñas.

Meshy puede servir para explorar siluetas y producir bases o props. Su salida no debe suponerse modular, optimizada ni compatible con el rig existente. Blender prepara una fuente maestra editable; Godot recibe GLB revisados, coherente con el pipeline existente y con la recomendación de glTF de [Godot](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html).

La documentación de [Meshy API](https://docs.meshy.ai/en/api/playground) indica que las llamadas usan créditos del plan; no se ha verificado el saldo ni las condiciones concretas de esta cuenta. Los [créditos mensuales](https://help.meshy.ai/en/articles/9991981-how-do-meshy-credits-work) se reinician y no se acumulan. Aprovechar el tiempo pagado exige una lista curada de assets y criterios de aceptación, no generación masiva sin dirección.

## Próximo hito recomendado

Una muestra jugable de 5–10 minutos en una porción pequeña de Costa del Naufragio: cámara y movimiento definitivos, geografía coherente con el agua/cartas, un cuerpo optimizado con variantes visibles, naufragio, sendero y primer destino, recolección e inventario legibles. Validarla antes de extenderla a ambos cuerpos, más biomas o a todo el continente.

Después, una ruta de producción, entrega y riesgo recuperable que demuestre la fantasía económica. El número de sectores exportados no equivale a contenido jugable ni a población que pueda sostenerlos.

## Incidencias de ejecución a investigar separadamente

La captura terminó con código 0, pero registró fallo al leer el almacén de certificados, una API obsoleta de interpolación y recursos de textura sin liberar al cerrar. No se consideran una validación limpia ni se atribuyen automáticamente al agua: pueden intervenir la escena de captura y el orden de liberación. Investigar su reproducción en el cierre normal del juego.
