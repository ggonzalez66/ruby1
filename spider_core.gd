extends "res://ruby_core.gd"

# Ruby central de la araña: la araña no se aturde (ni parries ni stagger le bajan postura o la frenan) y,
# mientras le quede alguna pata, nada puede arrancarle el núcleo (tampoco la ultimate).

func register_parry(_token: int = -1) -> bool:
	return false

func stagger(_seconds: float) -> void:
	pass

func claim_wrath(by: Node) -> bool:
	if enemy.legs_alive() > 0:
		return false
	return super(by)
