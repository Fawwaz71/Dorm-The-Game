extends Node
class_name InventoryComponent

var held_visual: Node3D = null
var held_item_id: String = ""

var item_database := {
	"acoustic": {"visual": preload("res://asset/interactable/item_visuals/acoustic_visual.tscn"), "physics": preload("res://asset/interactable/rigid_acoustic.tscn")},
	"guitar": {"visual": preload("res://asset/interactable/item_visuals/guitar_visual.tscn"), "physics": preload("res://asset/interactable/Rigid_guitar.tscn")},
	"broom": {"visual": preload("res://asset/interactable/item_visuals/broom_visual.tscn"), "physics": preload("res://asset/interactable/rigid_broom.tscn")},
	"trash": {"visual": preload("res://asset/interactable/item_visuals/trash_visual.tscn"), "physics": preload("res://asset/interactable/trash object/rigid_trash.tscn")},
	"key": {"visual": preload("res://asset/interactable/item_visuals/key_visual.tscn"), "physics": preload("res://asset/interactable/trash object/rigid_key.tscn")},
	"bottles": {"visual": preload("res://asset/interactable/trash object/bottles_visual.tscn"), "physics": preload("res://asset/interactable/trash object/rigid_bottles.tscn")},
	"dumbell_small": {"visual": preload("res://asset/interactable/item_visuals/dumbell_small_visual.tscn"), "physics": preload("res://asset/interactable/rigid_dumbell_small.tscn")}
}

func pick_up_weapon(p, world_item):
	held_item_id = world_item.get_meta("item_id")
	var key_id = world_item.get_meta("key_id") if world_item.has_meta("key_id") else ""
	world_item.queue_free()
	
	held_visual = item_database[held_item_id]["visual"].instantiate()
	p.hand.add_child(held_visual)
	held_visual.transform = Transform3D.IDENTITY
	if key_id != "": held_visual.set_meta("key_id", key_id)

# Inside InventoryComponent.gd

func drop_weapon(p):
	if !held_visual: return
	
	var key_id = held_visual.get_meta("key_id") if held_visual.has_meta("key_id") else ""
	var drop_transform = held_visual.global_transform
	
	# Check if we are looking at a wall/floor nearby to prevent dropping through walls
	var is_gentle = p.small_target.is_colliding()
	
	# Store ID before clearing
	var id_to_drop = held_item_id
	clear_held(p)
	
	var obj = item_database[id_to_drop]["physics"].instantiate()
	get_tree().current_scene.add_child(obj)
	
	# Set position: slightly in front of player to avoid self-collision
	if is_gentle:
		obj.global_transform.origin = p.small_target.get_collision_point() + p.small_target.get_collision_normal() * 0.2
	else:
		# Spawn at hand but move it slightly forward along the camera view
		obj.global_transform = drop_transform
		obj.global_position -= p.camera.global_transform.basis.z * 0.5 

	# Apply metadata
	obj.set_meta("item_id", id_to_drop)
	if key_id != "": obj.set_meta("key_id", key_id)
	
	# Physics Impulse
	if obj is RigidBody3D:
		if !is_gentle:
			# Throw it forward
			var throw_force = 4.0
			obj.apply_central_impulse(-p.camera.global_transform.basis.z * throw_force)
			# Add a little random torque for "natural" tumbling
			obj.apply_torque_impulse(Vector3(randf(), randf(), randf()) * 0.5)
			
func clear_held(_p):
	if held_visual: held_visual.queue_free()
	held_visual = null
	held_item_id = ""

func buy_item(p, item_id, qty):
	var prices = {"acoustic": 50, "guitar": 10, "broom": 15, "trash": 5}
	var cost = prices.get(item_id, 999) * qty
	if p.money >= cost:
		p.money -= cost
		p.sfx.pickup.play()
		for i in range(qty):
			var inst = item_database[item_id]["physics"].instantiate()
			get_tree().current_scene.add_child(inst)
			inst.global_position = p.object_spawn.global_position if p.object_spawn else p.global_position
			inst.set_meta("item_id", item_id)
