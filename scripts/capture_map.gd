extends SceneTree

const OUTPUT_DIR := "res://previews"
const OVERVIEW_FILE := "island-overview.jpg"
const DETAIL_FILE := "island-detail.jpg"


func _initialize() -> void:
	call_deferred("_capture_map")


func _capture_map() -> void:
	root.size = Vector2i(1600, 900)
	var packed_scene := load("res://scenes/main.tscn") as PackedScene
	if packed_scene == null:
		push_error("Could not load the main island scene.")
		quit(1)
		return

	var island := packed_scene.instantiate()
	root.add_child(island)
	# Freeze the showcase orbit so every screenshot is repeatable.
	island.set_process(false)

	# The island is procedurally generated in _ready(). Wait for the renderer
	# to submit several frames before reading the viewport texture.
	for frame in range(5):
		await process_frame

	var camera := island.get_node_or_null("TemporaryIslandOverviewCamera") as Camera3D
	if camera == null:
		push_error("The showcase camera was not created.")
		quit(1)
		return

	camera.current = true
	camera.fov = 54.0
	camera.position = Vector3(720.0, 504.0, 680.0)
	camera.look_at(Vector3(0.0, 8.0, 0.0), Vector3.UP)
	await process_frame
	var overview_error := _save_viewport(OVERVIEW_FILE)
	if overview_error != OK:
		push_error("Failed to save overview screenshot: %s" % error_string(overview_error))
		quit(1)
		return

	var focus_raw := OS.get_environment("MAP_CAPTURE_FOCUS")
	if not focus_raw.is_empty():
		var parts := focus_raw.split(",")
		if parts.size() == 3:
			var focus := Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())
			camera.fov = 58.0
			camera.position = focus + Vector3(105.0, 82.0, 112.0)
			camera.look_at(focus, Vector3.UP)
			for frame in range(3):
				await process_frame
			var detail_error := _save_viewport(DETAIL_FILE)
			if detail_error != OK:
				push_error("Failed to save detail screenshot: %s" % error_string(detail_error))
				quit(1)
				return

	print("MAP_SCREENSHOTS_SAVED: %s, %s" % [OVERVIEW_FILE, DETAIL_FILE])
	quit()


func _save_viewport(file_name: String) -> Error:
	var absolute_directory := ProjectSettings.globalize_path(OUTPUT_DIR)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if directory_error != OK:
		return directory_error
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		return ERR_CANT_CREATE
	var absolute_path := absolute_directory.path_join(file_name)
	return image.save_jpg(absolute_path, 0.92)
