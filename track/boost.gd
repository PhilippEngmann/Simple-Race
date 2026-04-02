extends Node3D

@export var kph_boost: float = 100.0

func _ready():
	var area = $Area3D
	area.body_entered.connect(_on_body_entered)
	
	# Make sure the Area3D doesn't act as a physical wall
	area.monitorable = false
	area.monitoring = true

func _on_body_entered(body):
	if body is RigidBody3D:
		var car_forward = -body.global_transform.basis.z.normalized()
		body.linear_velocity += car_forward * (kph_boost/3.6)
