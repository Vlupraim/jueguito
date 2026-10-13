# Costa del naufragio — pasada de entorno v2

La playa mantiene despejada la aparición y el paso hacia el barco. Detrás hay dunas con vegetación baja, grupos pequeños de árboles y laderas con una transición gradual entre suelo, pasto y roca. El objetivo es una costa templada legible y transitable, todavía con los modelos de prueba existentes.

La costa conserva 11 pinos talables `pine_tall_01`, con altura de 5.4–7.5 m, además de 20 piedras y 62 grupos de pasto de duna. Las tres acacias se retiraron porque corresponden a otro bioma. El primero está unos 32 m hacia el interior desde la aparición, en `(270, 240)` del sector `(27, 30)`. Cada pino tiene ID de recurso propio, tronco con colisión y conserva el sistema de tala, madera, tocón y reaparición.

### Ajuste de borde forestal v3

Los once pinos mantienen exactamente sus transformaciones e IDs. El pasto se extendió hacia la playa con un borde continuo e irregular que conecta los troncos con la cobertura del interior; se evita crear círculos verdes aislados bajo cada árbol. La franja baja junto al mar y la aparición siguen siendo arena. La prueba verifica que la textura dominante bajo cada pino sea pasto (slot 2), además de comprobar suelo seco y tala. Hay copia local del terreno anterior en `data/terrain3d_edit_backups/coast_pines_v3_before/`.

Para probar: abrir inventario con `I`, hacer clic en **Hacha de leñador** para equiparla, acercarse y hacer clic en un árbol. La tala dura siete segundos; el pino entrega cuatro unidades de madera. Los inventarios iniciales ya incluyen un hacha.

Los pinos tenían un atlas muy oscuro y reflejos intensos que producían brillo blanco. El material costero conserva las UV, aclara sus valores oscuros con una curva suave, reduce especular y usa iluminación envolvente/transmisión moderada para hojas. La silueta sigue siendo la del modelo original; una copa más natural requiere un modelo nuevo o una revisión de geometría.

## Pintura y continuidad

La primera combinación de musgo, pasto sombrío y lajas dejó manchas oscuras y franjas duras. La nueva pasada reemplaza esa distribución en tierra con arena, pasto, tierra y roca: la vegetación crece progresivamente entre alturas aproximadas de 6.1 y 11.8 m; la roca domina las pendientes de 22–38 grados. Ruido amplio introduce irregularidad discreta. El material Terrain3D reduce `blend_sharpness` a 0.05: con albedos de altura constante, el valor anterior concentraba demasiado la mezcla.

La comprobación de cuatro regiones encontró 170.286 píxeles de superficie cambiados. **Los bytes de los mapas de altura y los bits de navegación/agujeros siguen idénticos**. El barco, sus transformaciones y la máscara de agua se conservaron. Los tintes se dejaron casi neutros, manteniendo la humedad alpha. La tonalidad excesivamente oscura venía principalmente de la combinación de materiales anterior; las muestras de color del terreno próximas a la aparición eran blancas.

Hay copia local anterior en `data/terrain3d_edit_backups/coast_surface_v2_before/`; no se publica el directorio de copias. El autor `scripts/tools/editor/coastal_surface_pass.gd` reproduce la pasada; `validate_coastal_surface.gd` compara con esa copia local. El autor de objetos `author_tutorial_coast.gd` genera la escena de vegetación y pequeñas manchas de suelo bajo raíces. **No volver a ejecutar autores sobre cambios manuales sin revisar primero su alcance**: la escena guardada es el recurso de trabajo normal.

La vegetación vive en `scenes/world/sectors/handmade/tutorial_coast_dressing.tscn`, instanciada tanto en el sector jugable como en el workspace. Se puede abrir directamente en Godot para ajustar cada objeto. Si se esculpe terreno debajo, hay que volver a ajustar su altura.

## Mosaico blanco del workspace

La prueba reprodujo una pérdida de la lista de texturas al liberar el Terrain3D del juego y crear el del workspace usando la misma biblioteca. La recarga captura la lista **antes** de asignarla al binding nativo, reconstruye los arrays y desactiva el damero. Se aplica al abrir el workspace, al reimportar texturas y al volver a entrar al juego en el mismo proceso. Los objetos de textura actuales mantienen los ajustes manuales del dock cuando están disponibles. Esta corrección no modifica alturas ni pintura.

## Verificación

`tutorial_coast_playtest.tscn` verifica once pinos sobre pasto y suelo seco, IDs únicos, reconocimiento del hacha, animación, recompensa de madera y tocón. Después libera el mundo y carga el workspace en el mismo proceso, verificando los 25 slots y la ausencia del damero. Se capturó con D3D12 en la RTX 3050. Las pruebas de salto/cámara, agua, HUD y materiales también pasan con la nueva pintura.

Las capturas están en `art/environment/material_audit_v1/`, en la raíz: `costa_con_arboles_v1.png`, `tala_en_costa_v1.png` y `workspace_costa_v1.png`. La captura del workspace oculta sus guías sólo para inspeccionar el terreno; en el editor siguen disponibles.

Queda trabajo artístico en siluetas de árboles, riqueza del sotobosque y detalles del naufragio. Esta pasada deja una zona coherente para probar movimiento y tala; no pretende dar por finalizada toda la costa ni garantizar rendimiento en un PC antiguo.
