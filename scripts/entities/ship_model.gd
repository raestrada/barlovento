class_name ShipModelBuilder
extends RefCounted

static func build(ship: Ship, root: Node3D, thruster_lights: Array[Node3D]) -> void:
	match ship.faction:
		"acero":
			AceroModelBuilder.build(ship, root, thruster_lights)
		"vinculados":
			VinculadosModelBuilder.build(ship, root, thruster_lights)
		"marea_libre":
			MareaModelBuilder.build(ship, root, thruster_lights)
		_:
			AceroModelBuilder.build(ship, root, thruster_lights)
