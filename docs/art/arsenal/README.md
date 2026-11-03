# Arsenal del Gauntlet

Todo esto existe solo en el Gauntlet, salvo el ajuste del medidor de estilo, que vale para todo el juego. Las cifras son una primera pasada.

## Armas a distancia

Elegir un arma pide confirmación, porque reemplaza la actual (`upgrade_menu.gd`). Se puede volver a comprar la lanza. Si la lanza seguía lanzada, vuelve a la mano al cerrar el menú.

| Arma | Precio | Disparo | Enfriamiento |
| --- | --- | --- | --- |
| Lanza de jade | 8 | La de siempre: marca, atrae y se llama de vuelta | 1 s |
| Pistola | 14 | Semiautomática: un disparo por toque de RT. 1 de daño. El elemento sale cada 3 disparos | 0,12 s |
| Granada de hielo | 16 | 6 de daño en zona y 5 racimos de 2. Siempre hiela. Las paredes cubren | 4 s |
| Railgun | 18 | 12 de daño instantáneo a todos en línea, ignora escudos. Al conectar: 0,16 s de hitstop y retroceso | 1,8 s |

Los elementos del arma a distancia son 3 cartas aparte (12 rubíes), una por elemento, y el arma admite uno. Si cambias de arma lo conserva. La lanza aplica el elemento al clavarse sin hacer daño, y también al volver. La granada no ofrece hielo porque ya hiela.

## Enfoque (RB, `focus_spell.gd`)

Mantener RB gasta Enfoque y pone cámara lenta. Se corta al soltar o al vaciarse, y hay que volver a pulsar. Fuera del Gauntlet RB sigue siendo la cámara lenta libre.

- Máximo 100. Hacen falta 20 para lanzarlo.
- Gasta 25 por segundo real, o 34 con Reloj detenido.
- Recupera 2 por segundo sin lanzarlo, 2 por golpe y 30 por ejecución. Las balas de la pistola sin elemento no recargan.
- **Reloj detenido (22 rubíes):** enemigos, sus temporizadores y sus proyectiles se paran, y Viridy sigue a velocidad normal. Se puede golpear y ejecutar.

## Otras mejoras

| Mejora | Precio | Efecto |
| --- | --- | --- |
| Reserva de Enfoque | 9 | +40 de Enfoque máximo. Acumulable hasta 2 |
| Manto largo | 8 | 4 s más de invisibilidad |
| Temple elemental | 10 | Los elementos enemigos duran la mitad |

## Vida y postura por ronda (`gauntlet_director.gd`)

- **Vida:** ×1,25 en la ronda 1 y +0,2 por ronda (ronda 5: ×2,05).
- **Postura:** un parry abre al enemigo en las rondas 1 y 2; dos en la 3 y 4; tres desde la 5.
- **Guardianes:** +15 % de vida por ronda desde la 2, y su postura aguanta un 25 % más por ronda, hasta el doble.

## Variantes elementales

Cada enemigo puede salir como variante: 10 % en la ronda 1, +6 % por ronda, hasta 50 %. Se reconocen por el anillo y el tinte. No sufren su propio elemento, y golpes y proyectiles se lo aplican a Viridy (`player_ailments.gd`). Los guardianes no tienen variantes.

- **Fuego:** 2 de daño cada 0,6 s durante 2,4 s. No puede matar.
- **Hielo:** 65 % de velocidad durante 2,5 s. Con 3 acumulaciones queda congelada 0,9 s.
- **Electricidad:** con 3 marcas queda electrocutada 0,9 s.

## Estilo (`ferocity.gd`)

| Rango | D-B | A | S | SS | SSS |
| --- | --- | --- | --- | --- | --- |
| Lo que rinde una ganancia | 100 % | 90 % | 80 % | 65 % | 50 % |
| Margen antes de bajar | 0,8 s | 0,7 s | 0,55 s | 0,4 s | 0,3 s |

Desde S moverse ya no detiene la bajada, y por encima de S correr, volar y la velocidad no suman. Con golpes pesados cada 0,6 s y una ejecución cada 3 s, pasar de S a SSS cuesta 9 s en vez de 4,2 s.

## Fusileros

Disparan la misma bala que la pistola: trazador, 2100 px/s y 0,7 s de vida. Siguen avisando con el láser y haciendo 8 de daño. El rugido las devuelve a un máximo de 1800 px/s, para que no se salten al enemigo entre dos frames. En todo el juego, no solo en el Gauntlet.

## Capturas

`RUBY1_SKIP_COUNTDOWN=1 godot --path . --rendering-driver opengl3 --audio-driver Dummy -s res://tools/art/capture_arsenal.gd` escribe en `runtime/`.
