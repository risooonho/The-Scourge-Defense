extends Enemy

onready var stone_pivot = $StonePivot
onready var stone_spawner = $StonePivot/StoneSpawner

onready var stone_resource = preload("res://src/bullets/Stone.tscn")

func _ready():
	max_hp = 8
	base_damage = 2
	randomize()
	ATTACK_DIST = (randi() % 50) + 200
	randomize()
	PYLON_ATTACK_DIST = (randi() % 50) + 300

func _physics_process(delta):
	if (current_target != null and current_target_wr.get_ref()):
		stone_pivot.look_at(current_target.global_position)

func _on_AnimatedSprite_frame_changed():
	match sprite.animation:
		"attack":
			match sprite.get_frame():
				4:
#					pass
					spawn_bullet()

func _on_TargetResetTimer_timeout():
	change_target(Util.primary_target)
	has_been_attacked = false
	
func spawn_bullet():
	var bullet = stone_resource.instance()
	bullet.setup_values(global_position, (stone_spawner.global_position - stone_pivot.global_position).normalized(), base_damage)
	get_parent().get_parent().call_deferred("add_child", bullet)
