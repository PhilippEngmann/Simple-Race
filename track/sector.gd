extends Node3D

signal sector_entered(sector_name)

@export var sector_name: String = "Sector X"

func _ready():
	var area = $Area3D
	area.body_entered.connect(_on_body_entered)
	
	# Make sure the Area3D doesn't affect physics
	area.monitorable = false
	area.monitoring = true

func _on_body_entered(body):
	if body is RigidBody3D:
		print(sector_name + " entered!")
		emit_signal("sector_entered", sector_name)
