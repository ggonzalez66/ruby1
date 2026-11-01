# Sigilo y mejoras del Gauntlet

Todo esto existe solo en el Gauntlet. En las demás etapas los enemigos, los rubíes y las mejoras siguen igual: `Upgrades.active` es falso y los enemigos no tienen agente.

## Rubíes

- Cada ejecución da rubíes. La cadena (menos de 4 s entre ejecuciones) suma uno más por eslabón: 1, 2, 3…
- Un guardián da 10. Las ejecuciones con Wrath también cuentan.
- El contador está junto al de la oleada, y se reinicia al empezar una partida.

## Pantalla de mejoras (`upgrade_menu.gd`)

Se abre 1 s después de vencer al guardián, antes de los portales, porque el juego cuenta como «oleada» la ronda entera. Pausa el juego.

1. **Mejora gratis:** 3 cartas, eliges 1. No se puede saltar. Reroll por 5 rubíes.
2. **Tienda:** 3 cartas nuevas con precio. Se compran todas las que alcancen, con reroll y «Continuar».

| Mejora | Precio | Efecto |
| --- | --- | --- |
| Backflip / Frontflip fantasma | 8 | Invulnerable mientras gira el flip (no todo el salto) |
| Giro reflector | 8 | El screw attack devuelve proyectiles, sin gastar durabilidad |
| Lanza ardiente | 10 | La lanza quema (también la pistola) |
| Punta perforante | 10 | Atraviesa 1 enemigo más y hace más daño. Acumulable hasta 3 (también la pistola) |
| Estampida | 10 | Correr en SSS a través de un enemigo le hace 2 de daño base cada 0,5 s |
| Pistola | 14 | Reemplaza la lanza: apuntar + el botón de lanzar. 3 de daño, cada 0,3 s |
| Halcón espiritual | 14 | 4 de vida. Se lanza contra enemigos en alerta (3 de daño) |
| Sabueso espiritual | 14 | 5 de vida. Inmoviliza 3 s a un enemigo de suelo en alerta |
| Elemento en un ataque | 12 | Ver abajo |

**Elementos:** cada carta sale con un tipo de ataque libre al azar: ligeros, pesados (aéreo y de suelo) o uppercut. Cada tipo admite un elemento.

- **Electricidad:** +25 % de daño (×1,5 más contra máquinas). Salta a 2 enemigos cercanos con la mitad del daño. 3 marcas aturden 1 s (1,6 s a máquinas) y el aturdimiento salta a todos los cercanos.
- **Fuego:** 1 de daño cada 0,7 s durante 2,8 s. Contra bestias, ×1,5 al golpe y doble quemadura. Puede dejar en DYING.
- **Hielo:** ralentiza a la mitad y acumula. 3 acumulaciones congelan 3 s. Un pesado aéreo rompe el hielo: daño × 2 + 10. Después, 6 s de inmunidad al hielo.

El tipo de enemigo sale de `creature_kind`: por ahora solo el halcón es bestia y el resto, máquinas.

**Aliados:** solo atacan a enemigos en alerta, para no delatar a Viridy. Los proyectiles les quitan vida, y atacar a un enemigo que no esté aturdido les cuesta un contraataque. Reaparecen a los 12 s.

## Sigilo (`stealth_agent.gd`, `stealth_director.gd`)

Mientras un enemigo no descubre a Viridy su IA propia está suspendida (`ruby_core.ai_suspended`) y lo mueve su agente. Las oleadas ya no tienen los 2 s de preparación; los guardianes sí.

| Estado | Qué hace |
| --- | --- |
| Sin saber | Patrulla. Los fijos miran a un lado y a otro |
| Sospecha `?` | Viridy en la visión larga (460 px): se queda quieto 1,1 s |
| Investiga | Va al punto, mira 2,2 s y vuelve a patrullar |
| Descubre `!` | Viridy en la visión corta (210 px): corre su IA normal y carga la alarma |
| Caza | La perdió de vista 2 s, o hay alarma: va a la última posición conocida |

La visión es hacia donde mira, y por la espalda solo nota a Viridy a menos de 46 px. Los voladores ven en círculo hacia abajo (430 y 190 px). Los conos se dibujan en el suelo mientras no están en alerta.

**Ejecución por sorpresa:** un pesado ejecuta a cualquier enemigo normal que no esté descubriendo a Viridy, si no hay alarma. Invisible, ejecuta a cualquiera, aunque esté en alerta. El estallido de la ejecución sigue golpeando a los vecinos y los alerta. Una lanza clavada también alerta.

**Alarma:**
- Se llena en 7 s con un enemigo. Cada uno extra suma un 60 % de velocidad.
- Golpear a quien la carga la pausa 1,5 s. Matarlo la hace bajar (5 s de llena a vacía).
- El centinela la dispara de golpe al terminar su sirena.
- Llena: todos van a por Viridy. Se apaga tras 6 s sin que nadie la vea.
- **Precaución (25 s):** queda la silueta roja en su última posición, ven un 25 % más lejos y un descubrimiento activa la alarma al instante.
- Si solo quedan voladores, bajan a buscarla para que la oleada siempre se pueda terminar.

**Bushes:** hay 3, en el suelo (`BUSH_SPOTS`).
- Dentro es invisible al instante.
- Tras 2 s dentro, al salir conserva 6 s de invisibilidad. Si sale antes, la pierde.
- Cualquier ataque, lanzamiento o rugido la corta. Ese ataque aún puede ejecutar (0,6 s).
- Atacar dentro del bush la saca 0,8 s.

## Capturas

Están en `runtime/` (`tools/art/capture_stealth.gd`). Los bushes son dibujo procedural (`bush.gd`), sin sprite.
