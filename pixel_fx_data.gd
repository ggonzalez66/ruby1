extends RefCounted

# Generado por tools/art/export_pixelfx.py: hojas de PixelFX (MIT, patch-gg/pixelfx) en assets/fx/pixelfx.
# frame = tamaño de cada fotograma, pivot = origen del efecto dentro del fotograma (los pies o el centro).

const SHEETS := {
	"air_cut": {"frame": Vector2(53, 134), "columns": 30, "count": 30, "fps": 30, "pivot": Vector2(14, 126), "grey": true},  # ruby1/air-cut
	"big_explosion": {"frame": Vector2(309, 275), "columns": 6, "count": 50, "fps": 15, "pivot": Vector2(158, 241), "grey": false},  # explosions/big-explosion
	"bloom": {"frame": Vector2(123, 120), "columns": 16, "count": 50, "fps": 15, "pivot": Vector2(61, 108), "grey": false},  # nature/healing-bloom
	"bubbles": {"frame": Vector2(23, 81), "columns": 41, "count": 41, "fps": 30, "pivot": Vector2(12, 76), "grey": false},  # ruby1/bubble-trail
	"bullet_impact": {"frame": Vector2(120, 77), "columns": 17, "count": 20, "fps": 30, "pivot": Vector2(86, 63), "grey": true},  # impacts/bullet-impact
	"burn_away": {"frame": Vector2(320, 180), "columns": 6, "count": 46, "fps": 15, "pivot": Vector2(0, 0), "grey": true},  # transitions/burn-away
	"burning": {"frame": Vector2(48, 72), "columns": 14, "count": 14, "fps": 30, "pivot": Vector2(24, 66), "grey": false},  # status/burning
	"burst": {"frame": Vector2(212, 194), "columns": 9, "count": 40, "fps": 30, "pivot": Vector2(112, 97), "grey": true},  # explosions/plasma-explosion
	"charge": {"frame": Vector2(239, 158), "columns": 8, "count": 64, "fps": 30, "pivot": Vector2(123, 122), "grey": true},  # lightning/charge-up
	"collect": {"frame": Vector2(82, 92), "columns": 24, "count": 34, "fps": 30, "pivot": Vector2(38, 83), "grey": true},  # pickups/collect-burst
	"crit": {"frame": Vector2(178, 134), "columns": 11, "count": 20, "fps": 30, "pivot": Vector2(79, 104), "grey": true},  # impacts/crit-hit
	"dust": {"frame": Vector2(140, 46), "columns": 14, "count": 34, "fps": 30, "pivot": Vector2(71, 30), "grey": true},  # impacts/heavy-landing
	"embers": {"frame": Vector2(66, 88), "columns": 31, "count": 45, "fps": 30, "pivot": Vector2(33, 74), "grey": true},  # ruby1/ember-rise
	"energy_orb": {"frame": Vector2(22, 20), "columns": 12, "count": 12, "fps": 30, "pivot": Vector2(11, 10), "grey": true},  # ruby1/energy-orb
	"exclamation": {"frame": Vector2(54, 66), "columns": 37, "count": 43, "fps": 30, "pivot": Vector2(27, 86), "grey": true},  # ui/exclamation
	"explosion": {"frame": Vector2(219, 218), "columns": 9, "count": 72, "fps": 30, "pivot": Vector2(106, 174), "grey": false},  # explosions/small-explosion
	"firefly": {"frame": Vector2(18, 18), "columns": 60, "count": 60, "fps": 30, "pivot": Vector2(9, 8), "grey": false},  # ruby1/firefly
	"flame_pillar": {"frame": Vector2(173, 240), "columns": 11, "count": 45, "fps": 15, "pivot": Vector2(86, 216), "grey": false},  # fire/flame-pillar
	"heal": {"frame": Vector2(238, 120), "columns": 8, "count": 62, "fps": 30, "pivot": Vector2(119, 88), "grey": true},  # holy/heal-aoe
	"hit_heavy": {"frame": Vector2(95, 84), "columns": 21, "count": 22, "fps": 30, "pivot": Vector2(49, 68), "grey": true},  # impacts/blunt-hit
	"hit_spark": {"frame": Vector2(126, 74), "columns": 16, "count": 16, "fps": 30, "pivot": Vector2(36, 58), "grey": true},  # impacts/hit-spark
	"ice_block": {"frame": Vector2(80, 74), "columns": 9, "count": 9, "fps": 30, "pivot": Vector2(47, 52), "grey": false},  # ice/ice-shatter
	"ice_shatter": {"frame": Vector2(191, 111), "columns": 10, "count": 32, "fps": 15, "pivot": Vector2(60, 89), "grey": false},  # ice/ice-shatter
	"jade_blast": {"frame": Vector2(309, 275), "columns": 6, "count": 50, "fps": 15, "pivot": Vector2(158, 241), "grey": true},  # explosions/big-explosion
	"kick_arc": {"frame": Vector2(114, 90), "columns": 9, "count": 9, "fps": 30, "pivot": Vector2(3, 47), "grey": true},  # ruby1/kick-arc
	"leaf": {"frame": Vector2(18, 12), "columns": 36, "count": 36, "fps": 30, "pivot": Vector2(9, 6), "grey": false},  # ruby1/leaf
	"mane_wisp": {"frame": Vector2(14, 29), "columns": 18, "count": 18, "fps": 30, "pivot": Vector2(8, 24), "grey": true},  # ruby1/mane-wisp
	"muzzle": {"frame": Vector2(80, 64), "columns": 25, "count": 30, "fps": 30, "pivot": Vector2(37, 58), "grey": true},  # projectiles/muzzle-pistol
	"parry": {"frame": Vector2(177, 103), "columns": 11, "count": 26, "fps": 30, "pivot": Vector2(86, 87), "grey": false},  # impacts/parry
	"poof": {"frame": Vector2(95, 79), "columns": 21, "count": 40, "fps": 30, "pivot": Vector2(45, 67), "grey": true},  # spawn/poof
	"ripples": {"frame": Vector2(130, 52), "columns": 15, "count": 30, "fps": 15, "pivot": Vector2(65, 30), "grey": false},  # water/ripples
	"ruby_burst": {"frame": Vector2(108, 147), "columns": 18, "count": 33, "fps": 30, "pivot": Vector2(54, 74), "grey": true},  # ruby1/ruby-burst
	"shield": {"frame": Vector2(115, 82), "columns": 17, "count": 30, "fps": 30, "pivot": Vector2(21, 66), "grey": true},  # impacts/shield-block
	"shockwave": {"frame": Vector2(230, 64), "columns": 8, "count": 23, "fps": 30, "pivot": Vector2(115, 42), "grey": true},  # ruby1/shockwave
	"stunned": {"frame": Vector2(54, 42), "columns": 30, "count": 30, "fps": 15, "pivot": Vector2(26, 56), "grey": false},  # status/stunned
	"sunburst": {"frame": Vector2(114, 114), "columns": 17, "count": 60, "fps": 15, "pivot": Vector2(57, 57), "grey": false},  # holy/sunburst
	"time_stop": {"frame": Vector2(116, 118), "columns": 17, "count": 33, "fps": 15, "pivot": Vector2(58, 100), "grey": true},  # arcane/time-stop
	"warp_in": {"frame": Vector2(197, 135), "columns": 10, "count": 50, "fps": 15, "pivot": Vector2(95, 107), "grey": true},  # spawn/spawn-portal
	"zap": {"frame": Vector2(132, 108), "columns": 15, "count": 28, "fps": 30, "pivot": Vector2(76, 54), "grey": true},  # lightning/zap-hit
}
