# Plan por pilares y dirección artística — v0.1

Fecha: 13 de septiembre de 2026.
Estado: dirección visual de la propuesta 02 elegida explícitamente por el usuario: «La segunda, con formas simples y pinceladas discretas». Plan de implementación y cifras de alcance propuestos; sistemas aún no implementados por este plan. La elección aprueba el rumbo visual, no cada objeto o emblema de la ilustración.

## Decisiones expresadas por el usuario

- Empezar por un lineamiento artístico que permita producir con coherencia.
- MMORPG territorial de fantasía contenida: oficios, rutas comerciales, navegación, facciones, emboscadas y disputa por un reinado. Los dragones pertenecen a la visión, sin exigir que todo tenga un aspecto mágico.
- Personajes sencillos y personalización limitada, tomando la sencillez de Albion como referencia de alcance.
- Un cuerpo masculino y uno femenino; opciones de caracterización visibles y manejables.
- Explorar low poly con acabado pintado, pinceladas/desgaste discreto y bordes legibles.
- Priorizar comodidad de juego; un entorno atractivo debe acompañarla.
- Conservar el mundo por sectores y su herramienta de generación/edición.
- Usar Costa del Naufragio, sector `(27, 30)`, como lugar de prueba y tutorial. Es una parte real del mundo a la que se puede regresar.
- Mantener la dirección musical a cargo del usuario.

## Organización: tres pilares y un criterio transversal

| Pilar | Responsabilidad | Entregable inicial | Fuera de la primera entrega |
| --- | --- | --- | --- |
| 1. Identidad artística | Formas, materiales, paleta, luz, personajes y lenguaje de UI | Guía corta, lámina de referencia y pequeña escena de validación en Godot | Rediseñar todo el continente, todas las interfaces o producir un catálogo masivo |
| 2. Personaje e identidad del jugador | Cuerpos, rig, animaciones, apariencia modular y creador | Un cuerpo piloto con piezas intercambiables; después ambos cuerpos con el mismo nivel de acabado | Escultura facial libre, cambios arbitrarios de talla, físicas de cabello complejas |
| 3. Territorio, agua y cartografía | Fiabilidad espacial, edición, costa, navegación local y publicación de sectores | Terreno/agua/mapas coherentes en `(27, 30)`, con herramientas reutilizables | Esculpir manualmente los miles de sectores, océano volumétrico, navegación naval completa |

Comodidad y tutorial son un criterio transversal: movimiento, cámara, legibilidad, interacción y rendimiento se verifican en cada entrega. No se deja la jugabilidad para después de terminar el arte.

Empezar por arte significa fijar reglas y hacer una muestra pequeña. La producción extensa empieza solo después de comprobar que el personaje se controla bien y que el terreno, el agua y los mapas coinciden.

## Dirección artística propuesta

**Fantasía medieval marítima, de vida cotidiana y poder disputado, con formas simples y acabado pintado.**

Las referencias de intriga dinástica aportan tono y relaciones de poder. La identidad visual propia puede nacer de materiales locales, oficios, banderas, rutas, puertos y desgaste por uso. La presencia de un dragón será más significativa si lo habitual conserva una escala humana.

### Láminas

- [Propuesta 01](concepts/art_direction/costa_direction_01.png): exploración inicial de tono, más detallada de lo que conviene usar como presupuesto de producción.
- [Propuesta 02](concepts/art_direction/costa_direction_02.png): dirección elegida por el usuario, con grandes planos y menor ruido visual. Es la referencia vigente para las pruebas de producción.

![Propuesta 02](concepts/art_direction/costa_direction_02.png)

Son ilustraciones generadas para comunicar dirección. No son capturas de Godot, modelos terminados, texturas repetibles ni una nueva geografía aprobada. La composición, NPC, insignia del estandarte y accesorios son ilustrativos; no fijan símbolos, nombres, lore ni contenido obligatorio.

### Reglas de forma y personajes

- Siluetas claras; proporciones adultas simplificadas, con manos y cabeza suficientemente legibles a la distancia de cámara. Explorar unas 6,5–7 cabezas de altura, sin convertirlo todavía en una medida obligatoria.
- Cuerpos adecuados para habitantes de diferentes oficios. Una anatomía de culturista no tiene por qué ser la identidad universal de granjeros, navegantes y artesanos.
- Ropa funcional: lino/lana, cuero, madera, hierro y algunos metales de rango. Ambos cuerpos tienen ropa de calidad y cobertura equivalentes.
- Cabello mediante masas grandes que se reconozcan por contorno; pocos pliegues importantes en ropa.
- Bordes marcados por cambios de plano, contraste y algunos trazos de luz. Un contorno negro de pantalla completa queda como experimento, no como requisito.

### Materiales y pincelada

- Grandes variaciones de color; detalle medio solo donde ayude a reconocer el material. Los raspones son acentos en bordes y puntos de contacto, no ruido distribuido por toda la superficie.
- Materiales principalmente mates. Metal y agua conservan respuesta propia, sin brillo plástico en piel o tela.
- Pintar sombras locales suaves puede ayudar a definir formas; evitar sombras direccionales fuertes en texturas que luego contradigan la iluminación del juego.
- Las texturas de terreno deben repetirse sin costuras, sin perspectiva ni una composición de ilustración. Preparar base/albedo y, solo cuando aporte, normal y roughness con intensidad contenida.
- Un mapa conceptual de material no se importa directamente como textura final. Hay que probar repetición, escala y mezcla sobre el terreno real.

### Paleta piloto

| Función | Color orientativo |
| --- | --- |
| Carbón / textos oscuros | `#292C2C` |
| Piedra gris | `#68716C` |
| Lino / lectura clara | `#D5C3A0` |
| Arena | `#B89C6C` |
| Vegetación apagada | `#677051` |
| Mar | `#3D6870` |
| Óxido / cuero cálido | `#895844` |
| Latón / acento de UI | `#A58A55` |

Esta paleta sirve para el piloto costero, no para uniformar todos los biomas. Separar códigos funcionales de peligro, selección e interacción de los colores de facción. Las señales importantes necesitan forma/icono/texto además de color.

### Costa del piloto

La costa no se consigue únicamente pintando arena. Requiere una pendiente creíble, altura de agua compartida, una transición entre arena seca/húmeda y una espuma contenida. Trabajar una franja corta de playa, rocas y sendero en el terreno existente.

Kit inicial: arena seca, arena húmeda, tierra de sendero, pasto y roca. Añadir transiciones o variantes cuando la prueba muestre repetición, no por completar una biblioteca. Vegetación en grupos; espacios de descanso visual alrededor del personaje y objetivos.

### UI y mapas

Conservar el atlas inclinado como referencia de identidad. El minimapa tiene una función distinta: posición, dirección y destinos cercanos. Su inclinación y ornamento deben someterse a legibilidad. Textos, foco, estados y layout son controles de Godot; las imágenes aportan materialidad y símbolos, sin reemplazar el comportamiento.

## Personajes nuevos: Strongman como referencia técnica

**Dirección actualizada por el usuario:** crear personajes que se acerquen a la propuesta artística 02. El Strongman no convence como identidad visual; queda como referencia técnica de esqueleto, animaciones y equipamiento, no como requisito de anatomía para los nuevos cuerpos.

La inspección de la auditoría encontró una malla/material, 150.134 triángulos fuente, 24 articulaciones y ningún morph target. El número de triángulos no determina si se puede personalizar. Se pueden añadir cabellos como piezas externas incluso a ese cuerpo. El problema es cuánto cuesta adaptar anatomía, materiales, rostros, ropa y animaciones a una familia modular coherente.

Primera prueba de producción propuesta:

1. Recuperar en Blender el rig y las animaciones existentes sin modificar el GLB jugable. Completado: referencia editable en `art/characters/rig_reference/strongman_recovered_reference_v01.blend`, respecto de la raíz del repositorio; guardado y reapertura verificados con 24 huesos y 20 Actions. El informe adyacente registra estructura y hash del original.
2. Construir un cuerpo piloto de proporciones ordinarias y formas simples que siga la propuesta 02, con una túnica de náufrago. La malla nueva requiere pesos propios; el rig recuperado es candidato técnico, no garantía de compatibilidad automática.
3. Vincularlo al esqueleto candidato o adaptar el rig y retargetear si las proporciones lo exigen. Probar caminar, correr y recolectar antes de fabricar variantes.
4. Probar dos cabellos intercambiables, anclajes de herramienta y continuidad cabeza/cuello. Después extender el sistema al segundo cuerpo.

**Ruta propuesta:** Blender como archivo maestro y herramienta de construcción modular. Meshy es opcional para explorar una base visual, no un requisito ni la fuente automática del rig final. La recuperación conserva el skin importado del Strongman; todavía no demuestra la deformación de una malla nueva ni el retargeting.

### Cuerpo, ropa de náufrago y equipo

El personaje consta de un esqueleto que anima las mallas, una base corporal con cobertura mínima y piezas visibles de ropa. Los huesos no reemplazan la piel: cara, manos, cuello y cualquier parte descubierta necesitan geometría corporal.

El atuendo predeterminado será una túnica sencilla de náufrago, con cobertura de torso y cadera, y prendas inferiores/cobertura base para mantener el personaje vestido al cambiar equipo. Propuesta: túnica a media pierna con abertura suficiente para caminar, mangas simples y piernas cubiertas por una prenda básica; longitud y acabado se validan en el piloto. El vestuario debe adaptarse a ambos cuerpos.

Al equipar torso, pantalón o calzado, sustituir la pieza inicial correspondiente u ocultar las regiones cubiertas. No apilar permanentemente toda la túnica bajo toda armadura: atraviesa otras mallas y consume geometría sin utilidad. Accesorios como cinturón o capa sí pueden superponerse cuando fueron diseñados para convivir.

La ropa flexible comparte rig y pesos; una herramienta rígida sigue su anclaje de mano. El código actual busca `RightHand`/`LeftHand` y equivalentes: conservar ese contrato o adaptar explícitamente los anclajes y su calibración. No se ha transferido automáticamente el equipamiento de Godot al archivo Blender.

La primera túnica se deforma con el esqueleto, sin simulación física de tela. Revisar cadera, entrepierna, rodillas y axilas al correr, saltar y talar. Mantener fuentes completas en Blender aunque algunas superficies se oculten en runtime.

El esqueleto maestro es una decisión de producción que debe verificarse antes de fabricar ambos cuerpos. No se reutilizan automáticamente clips entre rigs distintos; primero se retargetean y validan. Conservar el pipeline actual por personaje hasta que el maestro sea una alternativa comprobada.

## Personalización v1 propuesta

| Opción | Alcance inicial propuesto | Implementación |
| --- | --- | --- |
| Cuerpo | Masculino y femenino | Dos mallas preparadas; cápsula de gameplay equivalente |
| Rostro | Dos variantes por cuerpo | Cabezas intercambiables con cuello compatible; deformaciones solo si resulta más sencillo mantenerlas |
| Cabello | Tres estilos por ajuste de cabeza, más sin cabello | Piezas ancladas; estilos pueden compartirse tras comprobar encaje |
| Colores | Paletas limitadas de piel, cabello e iris | Materiales o máscaras que separen las zonas editables |
| Ojos | Color y diferencias incluidas en los rostros | No controles libres de párpados ni distancias faciales |
| Barba | Opcional después de validar lo anterior | Piezas compatibles con cada rostro |

El creador muestra nombre y opciones disponibles, giro y acercamiento al rostro, y preview con la misma iluminación/materiales base que el juego. Cambiar una opción debe reflejarse inmediatamente. No ofrecer selectores sin variantes reales.

Guardar identificadores de cuerpo, rostro, cabello y colores, junto con una versión del esquema. No guardar una malla distinta por combinación. Los mismos datos deben reconstruir el personaje en menú, mundo y otros clientes. La selección estética no cambia ventajas, alcance o colisión.

Prueba de aceptación: todas las combinaciones disponibles se reconstruyen correctamente, conservan apariencia al cambiar de escena y sobreviven al guardado implementado; cabello sigue la cabeza; el color de ojos no tiñe la cara; no hay clipping evidente en animaciones principales ni herramienta despegada de la mano.

## Terreno: repartir trabajo manual y asistencia

No hace falta corregir todo el mundo ahora. Conservar el mapa macro y concentrarse en una zona pequeña del sector inicial. El resto puede permanecer como base generada hasta que sea necesario diseñar una ruta o asentamiento.

El usuario conserva la composición y esculpido autoral. El agente puede ayudar con diagnósticos de pendientes, discontinuidades, accesibilidad, objetos flotantes y concordancia cartográfica; también con herramientas de pintura, materiales y correcciones delimitadas. No toda pendiente fuerte es un defecto: un acantilado intencional se conserva, mientras una rampa tutorial impracticable requiere corrección.

La herramienta debería distinguir «detectar» de «aplicar»: mostrar una propuesta y un área afectada antes de modificar terreno. Nunca regenerar silenciosamente sectores editados.

### Contrato agua–terreno–mapas

1. Registrar rectángulo/escala del sector y cuerpos de agua autorizados con sus alturas. Documentar la relación entre los 5 km macro y las 512 unidades runtime antes de diseñar tiempos de viaje.
2. Generar la clasificación cartográfica a partir del terreno final y esos cuerpos de agua; mantener la conectividad prevista para no inundar depresiones interiores sin intención.
3. Reutilizar esos datos en agua y cartas; distinguir el umbral lógico de vadeo de la oscilación visual de olas.
4. Guardar resultados derivados por revisión del terreno/agua e invalidar solo las cachés afectadas.
5. Medir actualización del editor y recorrido jugable por separado. Reutilizar trabajo de máscaras y limitar reconstrucciones cuando sea posible.

Aceptación: esculpir una bahía cambia la carta correspondiente; una elevación queda seca en ambas representaciones; los marcadores mantienen posición al variar zoom; caminar no reconstruye el océano; cargar/guardar conserva el mismo borde; el mapa macro mantiene sus invariantes aprobadas.

## Tutorial compartido y progreso individual

El terreno `(27, 30)` forma parte del mundo y permite regreso. Cada personaje conserva su propio avance: movimiento aprendido, primera tala, primera extracción de piedra e interacción con un NPC, cuando existan esas mecánicas. Indicaciones o conversaciones pueden mostrarse solo a ese jugador sin duplicar el terreno.

**Propuesta de persistencia:** en un prototipo local pueden guardarse banderas para probar el recorrido. Para el MMO, el progreso y las recompensas que habilita deben pertenecer al personaje y persistirse/validarse en el servidor; el archivo local puede actuar como caché de preferencias o presentación. Copiar/cambiar de computador no debe reiniciar el progreso oficial ni permitir repetir recompensas.

El mock actual no satisface esa persistencia. Se registrará por separado el guardado provisional y la integración real, sin llamarlos equivalentes.

Tala ya tiene una base técnica. Minería y NPC son ampliaciones propuestas por este turno, no funcionalidades declaradas existentes. El primer recorrido añade cada una solo después de contar con interacción y respuesta visibles. Evitar que principiantes dependan de un recurso agotado por otros: definir reposición, nodos tutoriales o asignación individual de objetivo sin duplicar recompensas.

Volver al lugar no reinicia el tutorial. Puede ofrecerse repetir instrucciones sin volver a entregar recompensas. El texto de orientación se adapta al contrato de controles vigente.

## Orden de ejecución y puntos de revisión

| Etapa | Trabajo delimitado | Resultado comprobable para continuar |
| --- | --- | --- |
| A. Dirección — elección visual completada | Propuesta 02 elegida: formas simples y pinceladas discretas; reglas y alcance documentados | Validar su reproducción en Godot en la etapa B |
| B. Pruebas pequeñas | Nuevo cuerpo piloto con túnica y variación de cabello, usando el rig recuperado como candidato; materiales costeros sobre una muestra; encuadre de cámara objetivo | Validar base modular y acabado dentro de Godot, no únicamente por ilustraciones |
| C. Base espacial y control | Coherencia terreno/agua/cartas, escala documentada y migración a WASD/cámara/interacción | Recorrido corto cómodo, predecible y cartográficamente correcto |
| D. Piloto integrado | Un cuerpo con personalización funcional, materiales definitivos del piloto, naufragio/sendero y tala | Cinco a diez minutos de juego con identidad consistente |
| E. Completar alcance inicial | Segundo cuerpo, variantes, guardado de apariencia/progreso; piedra/NPC según disponibilidad | Ambos cuerpos y el recorrido tutorial acordado pasan las mismas pruebas |
| F. Extender | Aplicar kit a destinos/rutas contiguas necesarios | Cada ampliación reutiliza reglas y se justifica por una actividad jugable |

No se fija una fecha de entrega sin medir la prueba del rig, las texturas y la base espacial. El límite de producción lo dan las piezas enumeradas y sus criterios de aceptación.

Pruebas transversales: reconocer personaje/objetivos a tamaño de juego; comparar 720p y 1080p; caminar, girar, interactuar y abrir/cerrar UI sin entradas conflictivas; revisar deformaciones y clipping; medir una ruta reproducible con la cámara prevista. Las metas concretas de FPS y población se fijan tras seleccionar hardware objetivo y obtener una línea base.

## Acceso a Meshy y política de producción de assets

El usuario informa que Meshy y su bridge están abiertos. En la inspección de esta sesión no aparece una herramienta Meshy callable; el inventario de navegador solo expuso el navegador interno de Codex sin pestañas. Esto no prueba que el bridge esté apagado: falta identificar/conectar su interfaz a esta sesión. Blender sí se comprobó operativo durante la auditoría.

La planificación y la referencia visual no dependen del bridge. Cuando esté accesible, empezar por una única base o prop piloto con criterios concretos: silueta, pose, piezas separables, escala y export. Verificar el resultado en Blender antes de generar variantes adicionales. No asumir compatibilidad del rig, topología o materiales por la previsualización de Meshy.

Conservar fuentes originales, copias de trabajo y exports finales separados; no sobrescribir el único Strongman ni un terreno editado. Las láminas de este documento no consumieron créditos de Meshy.
