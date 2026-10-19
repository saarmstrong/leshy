extends RefCounted
const CAPACITY := 3
const STARTER = ["squirrel_bottle", "pliers", "hourglass"]
const DEFINITIONS = {
	"squirrel_bottle": {"name": "Bottled Squirrel", "description": "Break the seal. A free squirrel enters your hand. This does not replace your mandatory draw.", "target": "none"},
	"pliers": {"name": "Pliers", "description": "A small, unpleasant offering. Add 1 damage to your side of the balance.", "target": "none"},
	"scissors": {"name": "Scissors", "description": "Cut one active enemy creature from the board. Death sigils still resolve.", "target": "enemy"},
	"hourglass": {"name": "Hourglass", "description": "The opponent skips their next advance, attacks and reserve refill.", "target": "none"},
	"fan": {"name": "Bone Fan", "description": "Your creatures gain Airborne for this round's attacks. Mighty Leap still catches them.", "target": "none"},
	"fish_hook": {"name": "Fish Hook", "description": "Steal an active enemy into an empty slot in either of your rows. It keeps its damage and sigils.", "target": "enemy_slot"},
}
