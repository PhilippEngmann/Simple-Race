extends Node3D

@export var boost_strength: float = 1500.0

func _ready():
	var area = $Area3D
	area.body_entered.connect(_on_body_entered)
	
	# Make sure the Area3D doesn't act as a physical wall
	area.monitorable = false
	area.monitoring = true

func _on_body_entered(body):
	if body is RigidBody3D:
		var boost_direction = -body.global_transform.basis.z.normalized()
		body.apply_central_impulse(boost_direction * boost_strength)
		print("Boost applied to " + body.name)
