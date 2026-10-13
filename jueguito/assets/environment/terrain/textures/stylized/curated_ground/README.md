# Biblioteca curada de terreno pintado

Esta carpeta organiza las 100 texturas fuente de `kalponic_ground` sin modificar
ni borrar los originales. Las copias se separan por uso y reciben nombres
descriptivos para que puedan localizarse desde el panel FileSystem de Godot.

## Categorias

- `tierra`: tierra seca, barro, ceniza y variantes con gravilla.
- `arena_arcilla`: arena, playa y arcilla agrietada.
- `roca_acantilado`: superficies rocosas para pendientes, riscos y formaciones.
- `grava_cantos`: grava, cantos rodados y empedrados.
- `vegetacion_humedad`: roca con musgo, pasto rocoso y pantano.
- `especiales`: nieve, lava, terreno arcano, agua y calaveras.

`catalogo.csv` conserva la relacion con `Ground (N).png` mediante la columna
`id`. El estado indica:

- `activa`: ya existe entre los ocho slots originales de Terrain3D.
- `activa_nueva`: seleccion agregada en los slots 8 a 23 de Terrain3D.
- `biblioteca`: disponible para sustituir o agregar mas adelante.

Terrain3D admite hasta 32 texturas de terreno. El proyecto parte con ocho slots,
por lo que no conviene activar las 100 a la vez. Las candidatas priorizan
superficies legibles y diferentes entre si.
