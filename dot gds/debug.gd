extends Node

# Adjustable interval between kills
const KILL_INTERVAL := 0.3

var kill_timer: Timer = null
var enemies := []

func _ready():
	set_process_input(true)

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F11:
			kill_all_enemies()
			set_wave_to_10_and_spawn_boss()
		elif event.keycode == KEY_F10:
			print("[DEBUG] F10 pressed: Starting kill all enemies one by one.")
			start_kill_all_enemies()

func start_kill_all_enemies():
	enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.size() > 0:
		kill_timer = Timer.new()
		kill_timer.wait_time = KILL_INTERVAL
		kill_timer.one_shot = false
		kill_timer.timeout.connect(_on_kill_timer_timeout)
		add_child(kill_timer)
		kill_timer.start()

func _on_kill_timer_timeout():
	if enemies.size() > 0:
		var enemy = enemies.pop_front()
		if enemy and enemy.is_inside_tree():
			if enemy.has_method("take_damage"):
				enemy.take_damage(99999)
			else:
				enemy.queue_free()
	else:
		if kill_timer:
			kill_timer.stop()
			kill_timer.queue_free()
			kill_timer = null

func kill_all_enemies():
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		if enemy and enemy.is_inside_tree():
			if enemy.has_method("take_damage"):
				enemy.take_damage(99999)
			else:
				enemy.queue_free()

func set_wave_to_10_and_spawn_boss():
	var spawner = get_tree().get_first_node_in_group("spawner")
	if spawner:
		print("[DEBUG] Spawner found. Setting wave to 10 and spawning boss.")
		spawner.current_wave = 10
		if spawner.has_method("_start_boss_wave"):
			spawner._start_boss_wave()
		else:
			print("[DEBUG] Spawner does not have _start_boss_wave method!")
	else:
		print("[DEBUG] Spawner not found! Cannot set wave or spawn boss.")

# Call this function to start killing enemies one by one
# Example: $debug.start_kill_all_enemies()
