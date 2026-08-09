class_name SpikeHazard
extends Area3D
## Lethal hazard zone placed over the spike platform visuals. The hazard is
## fully independent of the spike mesh: plain wall/floor collision never kills,
## only overlap with this area. It detects players in both the solid and the
## phased RGB states, so a phased player still dies on contact.

## Damage dealt to a player on contact. Lethal by default.
@export var damage: int = 999

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		body.take_hazard_damage(damage)
