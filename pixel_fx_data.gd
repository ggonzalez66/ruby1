extends RefCounted

# Generado por tools/art/export_pixelfx.py: hojas de PixelFX (MIT, patch-gg/pixelfx) en assets/fx/pixelfx.
# frame = tamaño de cada fotograma, pivot = origen del efecto dentro del fotograma (los pies o el centro).

const SHEETS := {
	"big_explosion": {"frame": Vector2(309, 275), "columns": 6, "count": 50, "fps": 15, "pivot": Vector2(158, 241), "grey": false},  # explosions/big-explosion
	"bullet_impact": {"frame": Vector2(120, 77), "columns": 17, "count": 20, "fps": 30, "pivot": Vector2(86, 63), "grey": true},  # impacts/bullet-impact
	"burst": {"frame": Vector2(212, 194), "columns": 9, "count": 40, "fps": 30, "pivot": Vector2(112, 97), "grey": true},  # explosions/plasma-explosion
	"charge": {"frame": Vector2(239, 158), "columns": 8, "count": 64, "fps": 30, "pivot": Vector2(123, 122), "grey": true},  # lightning/charge-up
	"collect": {"frame": Vector2(82, 92), "columns": 24, "count": 34, "fps": 30, "pivot": Vector2(38, 83), "grey": true},  # pickups/collect-burst
	"crit": {"frame": Vector2(178, 134), "columns": 11, "count": 20, "fps": 30, "pivot": Vector2(79, 104), "grey": true},  # impacts/crit-hit
	"dust": {"frame": Vector2(140, 46), "columns": 14, "count": 34, "fps": 30, "pivot": Vector2(71, 30), "grey": true},  # impacts/heavy-landing
	"explosion": {"frame": Vector2(219, 218), "columns": 9, "count": 72, "fps": 30, "pivot": Vector2(106, 174), "grey": false},  # explosions/small-explosion
	"flame_pillar": {"frame": Vector2(173, 240), "columns": 11, "count": 45, "fps": 15, "pivot": Vector2(86, 216), "grey": false},  # fire/flame-pillar
	"heal": {"frame": Vector2(238, 120), "columns": 8, "count": 62, "fps": 30, "pivot": Vector2(119, 88), "grey": true},  # holy/heal-aoe
	"hit_heavy": {"frame": Vector2(95, 84), "columns": 21, "count": 22, "fps": 30, "pivot": Vector2(49, 68), "grey": true},  # impacts/blunt-hit
	"hit_spark": {"frame": Vector2(126, 74), "columns": 16, "count": 16, "fps": 30, "pivot": Vector2(36, 58), "grey": true},  # impacts/hit-spark
	"parry": {"frame": Vector2(177, 103), "columns": 11, "count": 26, "fps": 30, "pivot": Vector2(86, 87), "grey": false},  # impacts/parry
	"poof": {"frame": Vector2(95, 79), "columns": 21, "count": 40, "fps": 30, "pivot": Vector2(45, 67), "grey": true},  # spawn/poof
	"shield": {"frame": Vector2(115, 82), "columns": 17, "count": 30, "fps": 30, "pivot": Vector2(21, 66), "grey": true},  # impacts/shield-block
	"sunburst": {"frame": Vector2(114, 114), "columns": 17, "count": 60, "fps": 15, "pivot": Vector2(57, 57), "grey": false},  # holy/sunburst
	"warp_in": {"frame": Vector2(197, 135), "columns": 10, "count": 50, "fps": 15, "pivot": Vector2(95, 107), "grey": true},  # spawn/spawn-portal
	"zap": {"frame": Vector2(132, 108), "columns": 15, "count": 28, "fps": 30, "pivot": Vector2(76, 54), "grey": true},  # lightning/zap-hit
}
