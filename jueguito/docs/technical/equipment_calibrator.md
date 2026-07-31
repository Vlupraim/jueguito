# Calibrador visual de equipamiento

El addon `Jueguito Equipment Tools` separa el modelo fuente de su presentacion
cuando esta equipado. El GLB permanece intacto y cada ajuste visual se guarda en
una escena `*_held.tscn` editable y reutilizable.

## Flujo de autor

1. Abrir el dock **Equipo** en el editor de Godot.
2. Elegir Hacha, Espada, Escudo o Arco en **Preset**. Para otro recurso usar
   **Personalizado** e indicar personaje, GLB, hueso, salida y definicion.
3. Elegir **Una mano** o **Dos manos** y la mano donde se vera el modelo.
4. Pulsar **Crear / reconstruir espacio**.
5. En la escena abierta, seleccionar `HeldItemPivot`.
6. Usar los gizmos normales de mover, rotar y escalar.
7. Pulsar **Guardar item calibrado**.

El plugin genera `tools/equipment/equipment_calibration_workspace.tscn` como
espacio temporal de autor y guarda el resultado definitivo en la ruta indicada.
El workspace puede reconstruirse; el GLB fuente nunca se sobrescribe.

El arbol visible del espacio es:

```text
EquipmentCalibrationWorkspace
├── CharacterPreview
└── EquipmentPreviewAttachment
    └── ScaleCompensator
        └── HeldItemPivot
            └── ItemModel
```

`EquipmentPreviewAttachment` sigue el hueso elegido dentro del editor sin
modificar la escena importada del personaje.

## Runtime y persistencia

El runtime sigue creando un `BoneAttachment3D` en el hueso correspondiente. La
escena `*_held.tscn` ya contiene la transformacion visual, por lo que el catalogo
usa posicion y rotacion cero, y escala uno.

El estado persistente no guarda nodos ni transforms. Guarda solamente el ID del
item equipado por slot, por ejemplo `main_hand = lumberjack_axe`. Al cargar el
personaje se vuelve a instanciar la escena visual calibrada.

## Definiciones editables

Las definiciones viven en `resources/items/definitions/*.tres` y se editan desde
el Inspector. Para registrar un item nuevo no hace falta modificar el catalogo:
se puede duplicar un `.tres`, cambiar su nombre, icono, modelo fuente, escena
equipada, slots y huesos. `ItemCatalog` descubre esos recursos al iniciar.

Al guardar desde el plugin tambien se persiste la regla de manos:

- **Una mano + derecha**: solo puede ocupar `primary` (por ejemplo, espada).
- **Una mano + izquierda**: solo puede ocupar `secondary` (por ejemplo, escudo).
- **Dos manos**: se registra en `primary`, bloquea ambas ranuras y crea un solo
  modelo 3D en la mano visual elegida. El HUD muestra ambas manos reservadas.

Estas reglas forman parte de la definicion del item, por lo que siguen vigentes
al moverlo entre inventarios, guardarlo o volver a cargar el personaje. No hay
fallback automatico a la otra mano para items con una ranura fija.

## Probar cambios en gameplay

`Ctrl+S` solo guarda el workspace. Para exportar el ajuste hay que pulsar
**Guardar item calibrado**. Una partida abierta mantiene las escenas cargadas en
memoria: debe detenerse y ejecutarse de nuevo para ver el nuevo `*_held.tscn`.
No es necesario modificar ni guardar la escena del tutorial.
