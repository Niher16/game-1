# TimeOfDayUI.gd
# UI Display for the Enhanced Time of Day System
# Shows current time, weather, and provides visual controls

extends Control
# class_name TimeOfDayUI

# ===== UI REFERENCES =====
@onready var main_panel: Panel
@onready var time_label: Label
@onready var weather_label: Label
@onready var weather_icon: TextureRect
@onready var time_progress: ProgressBar
@onready var lighting_toggle: Button
@onready var weather_toggle: Button
@onready var auto_toggle: CheckBox

# ===== SYSTEM REFERENCE =====
var time_manager: EnhancedTimeOfDayManager

# ===== UI SETTINGS =====
@export var ui_position: Vector2 = Vector2(20, 20)
@export var auto_hide_duration: float = 5.0
@export var fade_duration: float = 0.5

var hide_timer: Timer
var is_ui_visible: bool = true

func _ready():
	# Add this line at the very beginning of _ready():
	get_tree().current_scene.add_child(self)
	# Find the time manager in the scene
	time_manager = get_tree().get_first_node_in_group("enhanced_time_manager")
	if not time_manager:
		# Fallback to regular time manager
		time_manager = get_tree().get_first_node_in_group("time_of_day_manager")
	
	if not time_manager:
		push_error("❌ No time manager found! Make sure to add TimeOfDayManager to scene.")
		return
	
	# Setup UI
	_create_ui_elements()
	_connect_signals()
	_setup_auto_hide()
	
	# Initial update
	_update_display()
	
	print("✅ TimeOfDayUI ready!")

func _create_ui_elements():
	"""Create all UI elements programmatically"""
	
	# Main panel container
	main_panel = Panel.new()
	main_panel.name = "TimeOfDayPanel"
	main_panel.size = Vector2(300, 180)
	main_panel.position = ui_position
	
	# Style the panel with a semi-transparent background
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0, 0, 0, 0.7)
	style_box.corner_radius_top_left = 10
	style_box.corner_radius_top_right = 10
	style_box.corner_radius_bottom_left = 10
	style_box.corner_radius_bottom_right = 10
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.3, 0.6, 1.0, 0.8)
	main_panel.add_theme_stylebox_override("panel", style_box)
	
	add_child(main_panel)
	
	# Time display label
	time_label = Label.new()
	time_label.text = "Time: Unknown"
	time_label.position = Vector2(15, 15)
	time_label.add_theme_font_size_override("font_size", 16)
	time_label.add_theme_color_override("font_color", Color.WHITE)
	main_panel.add_child(time_label)
	
	# Weather display label
	weather_label = Label.new()
	weather_label.text = "Weather: Clear"
	weather_label.position = Vector2(15, 40)
	weather_label.add_theme_font_size_override("font_size", 14)
	weather_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	main_panel.add_child(weather_label)
	
	# Progress bar for time visualization
	time_progress = ProgressBar.new()
	time_progress.size = Vector2(270, 20)
	time_progress.position = Vector2(15, 65)
	time_progress.min_value = 0
	time_progress.max_value = 7  # 8 time periods (0-7)
	time_progress.step = 1
	time_progress.value = 0
	main_panel.add_child(time_progress)
	
	# Lighting mode toggle button
	lighting_toggle = Button.new()
	lighting_toggle.text = "Toggle Day/Night"
	lighting_toggle.size = Vector2(130, 30)
	lighting_toggle.position = Vector2(15, 95)
	main_panel.add_child(lighting_toggle)
	
	# Weather toggle button
	weather_toggle = Button.new()
	weather_toggle.text = "Toggle Weather"
	weather_toggle.size = Vector2(130, 30)
	weather_toggle.position = Vector2(155, 95)
	main_panel.add_child(weather_toggle)
	
	# Auto-change checkbox
	auto_toggle = CheckBox.new()
	auto_toggle.text = "Auto Change"
	auto_toggle.position = Vector2(15, 135)
	auto_toggle.button_pressed = false
	main_panel.add_child(auto_toggle)
	
	# Instructions label
	var instructions = Label.new()
	instructions.text = "Press H to hide/show • L=Random • T=Toggle • W=Weather • 1-8=Time"
	instructions.position = Vector2(15, 155)
	instructions.add_theme_font_size_override("font_size", 10)
	instructions.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	main_panel.add_child(instructions)

func _connect_signals():
	"""Connect UI signals to time manager"""
	if not time_manager:
		return
	
	# Connect time manager signals
	if time_manager.has_signal("time_of_day_changed"):
		time_manager.time_of_day_changed.connect(_on_time_changed)
	
	if time_manager.has_signal("lighting_mode_changed"):
		time_manager.lighting_mode_changed.connect(_on_lighting_mode_changed)
	
	if time_manager.has_signal("weather_changed"):
		time_manager.weather_changed.connect(_on_weather_changed)
	
	# Connect UI element signals
	lighting_toggle.pressed.connect(_on_lighting_toggle_pressed)
	weather_toggle.pressed.connect(_on_weather_toggle_pressed)
	auto_toggle.toggled.connect(_on_auto_toggle_changed)

func _setup_auto_hide():
	"""Setup auto-hide functionality"""
	hide_timer = Timer.new()
	hide_timer.wait_time = auto_hide_duration
	hide_timer.one_shot = true
	add_child(hide_timer)
	hide_timer.timeout.connect(_hide_ui)
	
	# Start the timer
	hide_timer.start()

func _update_display():
	"""Update the UI display with current information"""
	if not time_manager:
		return
	
	# Update time label
	if time_label:
		var current_time = time_manager.get_current_time_name() if time_manager.has_method("get_current_time_name") else "Unknown"
		time_label.text = "Time: " + current_time
	
	# Update progress bar
	if time_progress and time_manager.has_method("get") and "current_time_index" in time_manager:
		time_progress.value = time_manager.current_time_index
	
	# Update lighting toggle button text
	if lighting_toggle:
		var is_day_active = time_manager.is_day_lighting_active if "is_day_lighting_active" in time_manager else false
		lighting_toggle.text = "Switch to Night" if is_day_active else "Switch to Day"
		lighting_toggle.modulate = Color.YELLOW if is_day_active else Color.CYAN
	
	# Update auto toggle
	if auto_toggle and time_manager.has_method("get") and "auto_change_enabled" in time_manager:
		auto_toggle.button_pressed = time_manager.auto_change_enabled

func _on_time_changed(new_time: String):
	"""Handle time change signal"""
	_update_display()
	_show_ui_temporarily()
	
	# Create a brief visual feedback
	_create_time_change_effect(new_time)

func _on_lighting_mode_changed(is_day_mode: bool):
	"""Handle lighting mode change"""
	_update_display()
	_show_ui_temporarily()
	
	# Update panel border color based on mode
	if main_panel:
		var style_box = main_panel.get_theme_stylebox("panel") as StyleBoxFlat
		if style_box:
			style_box.border_color = Color.YELLOW if is_day_mode else Color.CYAN

func _on_weather_changed(weather_type: String):
	"""Handle weather change signal"""
	if weather_label:
		weather_label.text = "Weather: " + weather_type
		
		# Change color based on weather
		match weather_type.to_lower():
			"rain":
				weather_label.add_theme_color_override("font_color", Color.CYAN)
			"snow":
				weather_label.add_theme_color_override("font_color", Color.WHITE)
			"fog":
				weather_label.add_theme_color_override("font_color", Color.GRAY)
			"cloudy":
				weather_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
			_:
				weather_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	
	_show_ui_temporarily()

func _on_lighting_toggle_pressed():
	"""Handle lighting toggle button press"""
	if time_manager and time_manager.has_method("toggle_lighting_mode"):
		time_manager.toggle_lighting_mode()

func _on_weather_toggle_pressed():
	"""Handle weather toggle button press"""
	# Simulate pressing W key for weather toggle
	var input_event = InputEventKey.new()
	input_event.keycode = KEY_W
	input_event.pressed = true
	get_viewport().push_input(input_event)

func _on_auto_toggle_changed(button_pressed: bool):
	"""Handle auto-change toggle"""
	if time_manager and "auto_change_enabled" in time_manager:
		time_manager.auto_change_enabled = button_pressed
		
		# Start or stop auto timer if it exists
		if time_manager.has_method("get") and "auto_timer" in time_manager and time_manager.auto_timer:
			if button_pressed and time_manager.is_day_lighting_active:
				time_manager.auto_timer.start()
			else:
				time_manager.auto_timer.stop()

func _create_time_change_effect(time_name: String):
	"""Create a visual effect when time changes"""
	var effect_label = Label.new()
	effect_label.text = time_name
	effect_label.add_theme_font_size_override("font_size", 24)
	effect_label.add_theme_color_override("font_color", Color.YELLOW)
	effect_label.position = Vector2(get_viewport().size.x / 2, 100)
	effect_label.anchor_left = 0.5
	effect_label.anchor_right = 0.5
	
	get_tree().current_scene.add_child(effect_label)
	
	# Animate the effect
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect_label, "modulate:a", 0.0, 2.0)
	tween.tween_property(effect_label, "position:y", 50, 2.0)
	tween.tween_callback(effect_label.queue_free).set_delay(2.0)

func _show_ui_temporarily():
	"""Show UI temporarily and reset hide timer"""
	if not is_ui_visible:
		_show_ui()
	
	# Reset the hide timer
	if hide_timer:
		hide_timer.start()

func _hide_ui():
	"""Hide the UI with fade effect"""
	if not is_ui_visible:
		return
	
	is_ui_visible = false
	var tween = create_tween()
	tween.tween_property(main_panel, "modulate:a", 0.3, fade_duration)

func _show_ui():
	"""Show the UI with fade effect"""
	if is_ui_visible:
		return
	
	is_ui_visible = true
	var tween = create_tween()
	tween.tween_property(main_panel, "modulate:a", 1.0, fade_duration)

func _input(event):
	"""Handle UI-specific input"""
	if not event is InputEventKey or not event.pressed:
		return
	
	match event.keycode:
		KEY_H:
			# Toggle UI visibility
			if is_ui_visible:
				_hide_ui()
				hide_timer.stop()
			else:
				_show_ui()
				hide_timer.start()
		
		KEY_L, KEY_T, KEY_W, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8:
			# Show UI temporarily when time controls are used
			_show_ui_temporarily()

# ===== UTILITY FUNCTIONS =====
func set_ui_position(new_position: Vector2):
	"""Set the UI position"""
	ui_position = new_position
	if main_panel:
		main_panel.position = ui_position

func set_auto_hide_duration(duration: float):
	"""Set how long before UI auto-hides"""
	auto_hide_duration = duration
	if hide_timer:
		hide_timer.wait_time = auto_hide_duration
