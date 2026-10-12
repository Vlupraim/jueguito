# Referencia técnica recuperada

`strongman_recovered_reference_v01.blend` es una importación editable del GLB que ya utiliza el juego. No es un personaje nuevo ni un cambio del asset de producción.

- 24 huesos, 20 Actions conservadas con Fake User.
- Malla `char1` vinculada al armature, con 24 grupos de vértices.
- El importador añadió una forma auxiliar `Icosphere` en `glTF_not_exported`; no forma parte del cuerpo jugable.
- Archivo guardado y reabierto para comprobar conservación de huesos y Actions.
- El hash del GLB original permaneció igual. Véase `recovery_report.json`.
- No se realizó todavía QA visual completo de las animaciones ni se transfirieron pesos a otro cuerpo.

Uso previsto: referencia/donante técnico para cuerpos nuevos según la propuesta artística 02, con túnica de náufrago y apariencia modular. Mantener la referencia intacta y trabajar en archivos hermanos versionados.

Los anclajes y la calibración de armas viven también en Godot; esta recuperación no incorpora esos nodos o ajustes automáticamente. Las mallas nuevas necesitan pesos propios y, si cambian las proporciones del rig, adaptación de animaciones.

Script reproducible: `scripts/recover_character_reference.py`, relativo a la raíz del repositorio. Requiere Blender y rechaza sobrescribir esta versión.
