# Enemigos v2 y guardián mecha

Son los conceptos del usuario, inspirados en los roles de Cogmind. El Bastión ya existía: es el escudero (`shield_bearer.gd`). Todos usan `ruby_core.gd`, así que se aplican las reglas habituales: OPEN con el parry, DYING a cero de vida y ejecución con un pesado.

| Enemigo | Script | Vida | Comportamiento |
| --- | --- | --- | --- |
| Centinela | `sentinel.gd` | 5 | Patrulla su plataforma. Al ver a Viridy carga una alarma de 0,9 s (sirena, «!!»). Si termina, alerta a los enemigos en 1100 px durante 8 s (ven 2,5× más lejos) y, la primera vez, trae dos refuerzos (un sabueso y un perseguidor). Golpearlo mientras carga corta la alarma. No ataca. |
| Fusilero | `rifleman.gd` | 8 | Mantiene unos 380 px de distancia y retrocede si Viridy se acerca. Apunta 0,8 s con láser; la mira queda fija los últimos 0,22 s. Dispara una ráfaga de 3 balas de 8 de daño, que el rugido devuelve. Recarga en 1,5 s. Dispara en cualquier ángulo. |
| Aguijón | `stinger.gd` | 3 | En enjambre. Orbita alrededor de Viridy (160 px), se fija 0,5 s con una línea roja y embiste en línea recta (8 de daño). Hereda del halcón el aturdimiento al golpearlo y el desvío con el rugido. |
| Restaurador | `restorer.gd` | 14 | Vuela hasta el aliado más dañado y lo repara (+1 cada 0,35 s). No repara a enemigos en DYING ni a guardianes. Huye si Viridy está a menos de 210 px. Acorralado (menos de 95 px durante 0,35 s), carga 0,55 s y suelta una descarga de radio 92 y 10 de daño. Se parrea, y golpearlo mientras carga la corta. |
| Sabueso | `hound.gd` | 6 | Rápido (270 px/s) y sube a plataformas de un salto. Se agazapa 0,4 s y se lanza. Si alcanza a Viridy la inmoviliza en el suelo: no quita vida, pero los demás le pegan. Machacar el ligero 7 veces la suelta; si no, se suelta sola a los 3,5 s. El rugido explosivo parrea el salto (lo aturde y abre el rubí) y la guardia lo bloquea. |

**Inmovilización** (`movimiento.gd`: `pin()`, `release_pin()`, `_update_pin()`):
- **Mientras dura:** Viridy no se mueve ni ataca, muestra la pose de golpe y un aviso «¡MACHACA X! ×n».
- **No la atrapan** con Wrath, durante una ejecución, en los frames del rugido ni con invulnerabilidad.
- **Al soltarse** tiene 0,45 s de invulnerabilidad para que no la vuelvan a atrapar al momento.

## Guardián mecha (`boss_mecha.gd`)

Tiene 120 de vida y forma parte del selector de guardianes (índice 3). El trío sigue siendo pesado, ágil y arquero (`TRIO = 5`, `TRIO_MEMBERS`), y `forced_boss = 4` sigue significando «uno no vencido».

- **Puñetazo:** aviso de 0,6 s con el puño brillando. Embiste hasta 360 px inclinado hacia delante, y golpean el puño y el frente del cuerpo (24 de daño). Parreado, el mecha queda aturdido.
- **Martillazo:** aviso de 0,8 s con el puño en alto. Golpea el suelo delante (26 de daño en 150 px) y lanza una onda baja de 70 px de alto que se salta (18 de daño).
- **Salva de misiles** (`missile.gd`): aviso de 0,7 s, «¡MISILES!». Dispara 5 misiles que suben y caen sobre cruces rojas repartidas alrededor de Viridy (14 de daño, radio 48). El rugido los devuelve contra el mecha. La prefiere de lejos o si Viridy está más arriba, con 6 s de reutilización.

## Gauntlet

| Desde la ronda | Novedad |
| --- | --- |
| 1 | Fusileros (1 + ronda/3) |
| 2 | Sabuesos, un enjambre de 2 a 5 aguijones y un centinela en una plataforma baja (dos desde la 4) |
| 3 | Restauradores |
| 4 | Fusileros también en las plataformas altas |

Se redujeron un poco los perseguidores y los tiradores antiguos. Los refuerzos del centinela cuentan para la oleada (`add_reinforcement`).

## Arte

Son sprites hechos con SDXL más el LoRA de pixel art, en `tools/art/enemy_art.py` (con nuevos prompts y cajas). Las variantes crudas están en `~/ruby1_referencias/enemigos`.

| Sprite | Semilla elegida | Notas |
| --- | --- | --- |
| `hound.png` | 43 | Reflejada (`:flip`) |
| `sentinel.png` | 43 | |
| `rifleman.png` | 54 | Segunda tanda, de perfil apuntando |
| `stinger.png` | 42 | |
| `restorer.png` | 42 | |
| `mecha.png` | 54 | Segunda tanda, de perfil con el puño gigante |

Las capturas del juego están en `runtime/` (`tools/art/capture_new_enemies.gd`): la alineación de enemigos, el mecha avisando y lanzando misiles, el sabueso inmovilizando, el galope de Wrath y el dash.

## Otros cambios de esta tanda

- **Wrath:** por el suelo la bestia galopa con las patas en el suelo, a 300 px de celda, y la captura tiene radio 58.
- **Dash:** usa solo `viridy_dash.png`.
- **Rugido orgulloso** (`growl`): vuelve al registro grave (de 104 a 80 Hz) con fritura fricativa y soplido.
- **Aim:** mientras LT siga pulsado, RT no dashea ni corre.
- **`boss_spawner.clear_bosses()`:** ignora guardianes ya liberados. Antes, el `_on_reset` del mecha cerraba el juego en ese caso.

`tests/integration/test_new_enemies.gd` cubre todo esto (31 checks).
