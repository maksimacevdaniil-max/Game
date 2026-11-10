extends Node3D
## Stage 1 — large open-world island, inspired by the atmosphere of The Forest.
## Original map layout and assets. Mobile-friendly MultiMesh vegetation.
## The rotating overview camera is a temporary showcase, not player controls.

const GRID_X := 280
const GRID_Z := 240
const WORLD_X := 700.0
const WORLD_Z := 600.0
const ISLAND_RX := 652.0
const ISLAND_RZ := 556.0
const SEA_LEVEL := -3.0

var _rng := RandomNumberGenerator.new()
var _height_noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()
var _camera: Camera3D
var _orbit_time := 0.0

var _terrain_material: StandardMaterial3D
var _sand_material: StandardMaterial3D
var _rock_material: StandardMaterial3D
var _trunk_material: StandardMaterial3D
var _pine_material: StandardMaterial3D
var _pine_light_material: StandardMaterial3D
var _bush_material: StandardMaterial3D
var _water_material: ShaderMaterial
var _river_material: StandardMaterial3D
var _rock_mesh: SphereMesh
var _bush_mesh: SphereMesh
var _grass_mesh: CylinderMesh


func _ready() -> void:
	_rng.seed = 14071986
	_height_noise.seed = 92841
	_height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_height_noise.frequency = 0.0034
	_height_noise.fractal_octaves = 5
	_height_noise.fractal_gain = 0.52
	_height_noise.fractal_lacunarity = 2.05

	_detail_noise.seed = 77193
	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail_noise.frequency = 0.016
	_detail_noise.fractal_octaves = 3
	_detail_noise.fractal_gain = 0.48

	_create_materials()
	_create_atmosphere()
	_create_terrain()
	_create_ocean()
	_create_lake()
	_create_river()
	_scatter_conifer_forest()
	_scatter_broadleaf_trees()
	_scatter_understory()
	_scatter_rocks_and_logs()
	_create_cave_system()
	_create_coastal_camp()
	_create_plane_wreck()
	_create_swamp_region()
	_create_abandoned_research_site()
	_create_trails()
	_create_showcase_camera()


func _process(delta: float) -> void:
	_orbit_time += delta
	if is_instance_valid(_camera):
		var angle := 0.24 + _orbit_time * 0.009
		var distance := 940.0 + sin(_orbit_time * 0.08) * 12.0
		_camera.position = Vector3(
			cos(angle) * distance,
			504.0 + sin(_orbit_time * 0.12) * 16.0,
			sin(angle) * distance
		)
		_camera.look_at(Vector3(0.0, 8.0, 0.0), Vector3.UP)


func _create_materials() -> void:
	_terrain_material = StandardMaterial3D.new()
	_terrain_material.vertex_color_use_as_albedo = true
	_terrain_material.roughness = 1.0

	_sand_material = StandardMaterial3D.new()
	_sand_material.albedo_color = Color(0.42, 0.37, 0.29)
	_sand_material.roughness = 0.98

	_rock_material = StandardMaterial3D.new()
	_rock_material.albedo_color = Color(0.27, 0.29, 0.28)
	_rock_material.roughness = 0.97

	_trunk_material = StandardMaterial3D.new()
	_trunk_material.albedo_color = Color(0.22, 0.16, 0.12)
	_trunk_material.roughness = 1.0

	_pine_material = StandardMaterial3D.new()
	_pine_material.albedo_color = Color(0.045, 0.16, 0.105)
	_pine_material.roughness = 0.96

	_pine_light_material = StandardMaterial3D.new()
	_pine_light_material.albedo_color = Color(0.075, 0.205, 0.125)
	_pine_light_material.roughness = 0.95

	_bush_material = StandardMaterial3D.new()
	_bush_material.albedo_color = Color(0.105, 0.205, 0.105)
	_bush_material.roughness = 1.0

	_river_material = StandardMaterial3D.new()
	_river_material.albedo_color = Color(0.075, 0.22, 0.24)
	_river_material.roughness = 0.16
	_river_material.metallic = 0.1
	_river_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var water_shader := Shader.new()
	water_shader.code = """
shader_type spatial;
render_mode cull_disabled;
void vertex() {
	float long_wave = sin(VERTEX.x * 0.035 + TIME * 0.48) * 0.11;
	float cross_wave = cos(VERTEX.z * 0.043 + TIME * 0.39) * 0.075;
	VERTEX.y += long_wave + cross_wave;
}
void fragment() {
	float ripple = 0.5 + 0.5 * sin(UV.x * 108.0 + UV.y * 73.0 + TIME * 0.4);
	vec3 deep = vec3(0.012, 0.075, 0.09);
	vec3 shallow = vec3(0.035, 0.19, 0.19);
	ALBEDO = mix(deep, shallow, ripple * 0.38);
	ROUGHNESS = 0.18;
	METALLIC = 0.13;
}
"""
	_water_material = ShaderMaterial.new()
	_water_material.shader = water_shader

	_rock_mesh = SphereMesh.new()
	_rock_mesh.radius = 1.0
	_rock_mesh.height = 2.0
	_rock_mesh.radial_segments = 9
	_rock_mesh.rings = 6

	_bush_mesh = SphereMesh.new()
	_bush_mesh.radius = 1.0
	_bush_mesh.height = 2.0
	_bush_mesh.radial_segments = 8
	_bush_mesh.rings = 5

	_grass_mesh = CylinderMesh.new()
	_grass_mesh.top_radius = 0.015
	_grass_mesh.bottom_radius = 0.12
	_grass_mesh.height = 0.62
	_grass_mesh.radial_segments = 4


func _create_atmosphere() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.105, 0.19, 0.25)
	sky_material.sky_horizon_color = Color(0.52, 0.59, 0.57)
	sky_material.ground_bottom_color = Color(0.075, 0.095, 0.085)
	sky_material.ground_horizon_color = Color(0.31, 0.37, 0.32)
	sky.sky_material = sky_material

	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.68
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.43, 0.51, 0.48)
	environment.fog_density = 0.0018
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "OvercastForestSun"
	sun.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	sun.light_color = Color(0.79, 0.84, 0.78)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 230.0
	add_child(sun)


func _create_terrain() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	for z_index in range(GRID_Z + 1):
		var z := -WORLD_Z + (float(z_index) / float(GRID_Z)) * WORLD_Z * 2.0
		for x_index in range(GRID_X + 1):
			var x := -WORLD_X + (float(x_index) / float(GRID_X)) * WORLD_X * 2.0
			surface.set_color(_terrain_color(x, z))
			surface.add_vertex(Vector3(x, _height_at(x, z), z))

	for z_index in range(GRID_Z):
		for x_index in range(GRID_X):
			var a := z_index * (GRID_X + 1) + x_index
			var b := a + 1
			var c := a + GRID_X + 1
			var d := c + 1
			surface.add_index(a)
			surface.add_index(c)
			surface.add_index(b)
			surface.add_index(b)
			surface.add_index(c)
			surface.add_index(d)

	surface.generate_normals()
	var terrain := MeshInstance3D.new()
	terrain.name = "HugeIslandTerrain"
	terrain.mesh = surface.commit()
	terrain.material_override = _terrain_material
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(terrain)
	terrain.create_trimesh_collision()


func _height_at(x: float, z: float) -> float:
	var nx := x / ISLAND_RX
	var nz := z / ISLAND_RZ
	var radial := sqrt(nx * nx + nz * nz)
	var coast_noise := _height_noise.get_noise_2d(x * 0.52, z * 0.52) * 0.027
	var coast := radial + coast_noise
	var land := 1.0 - smoothstep(0.91, 1.055, coast)

	var lake_basin := 7.4 * exp(-pow((x - 236.0) / 66.0, 2.0) - pow((z + 8.0) / 48.0, 2.0))
	var central_ridge := 28.0 * exp(-pow((x + 50.0) / 224.0, 2.0) - pow((z + 76.0) / 180.0, 2.0))
	var north_peak := 34.0 * exp(-pow((x - 130.0) / 156.0, 2.0) - pow((z + 284.0) / 116.0, 2.0))
	var west_ridge := 18.0 * exp(-pow((x + 350.0) / 124.0, 2.0) - pow((z + 30.0) / 250.0, 2.0))
	var southern_hills := 8.0 * exp(-pow((x - 40.0) / 320.0, 2.0) - pow((z - 300.0) / 132.0, 2.0))
	var broad_hills := max(_height_noise.get_noise_2d(x, z), -0.35) * 10.0
	var fine_detail := _detail_noise.get_noise_2d(x, z) * 1.35
	var elevation := 0.7 + central_ridge + north_peak + west_ridge + southern_hills + broad_hills + fine_detail - lake_basin
	return lerp(SEA_LEVEL - 0.8, elevation, land)


func _terrain_color(x: float, z: float) -> Color:
	var height := _height_at(x, z)
	var slope := _slope_at(x, z)
	var grass := Color(0.15, 0.235, 0.145)
	var dark_grass := Color(0.075, 0.145, 0.095)
	var moss := Color(0.23, 0.265, 0.16)
	var sand := Color(0.43, 0.365, 0.265)
	var stone := Color(0.31, 0.325, 0.31)
	var high_stone := Color(0.235, 0.255, 0.25)

	if height < 2.1:
		var beach_mix := clamp((height + 1.4) / 3.5, 0.0, 1.0)
		return sand.lerp(grass, beach_mix)
	var color := dark_grass.lerp(grass, clamp((height - 2.0) / 12.0, 0.0, 1.0))
	if height > 16.0 or slope > 1.75:
		color = color.lerp(stone, clamp(max((height - 16.0) / 18.0, (slope - 1.4) / 2.2), 0.0, 0.92))
	if height > 31.0:
		color = color.lerp(high_stone, clamp((height - 31.0) / 15.0, 0.0, 0.75))
	var moss_factor := _detail_noise.get_noise_2d(x * 2.0, z * 2.0) * 0.055
	return Color(
		clamp(color.r + moss_factor, 0.0, 1.0),
		clamp(color.g + moss_factor, 0.0, 1.0),
		clamp(color.b + moss_factor, 0.0, 1.0)
	)


func _slope_at(x: float, z: float) -> float:
	var dx := _height_at_raw(x + 2.0, z) - _height_at_raw(x - 2.0, z)
	var dz := _height_at_raw(x, z + 2.0) - _height_at_raw(x, z - 2.0)
	return Vector2(dx, dz).length() * 0.25


func _height_at_raw(x: float, z: float) -> float:
	var nx := x / ISLAND_RX
	var nz := z / ISLAND_RZ
	var radial := sqrt(nx * nx + nz * nz)
	var coast := radial + _height_noise.get_noise_2d(x * 0.52, z * 0.52) * 0.027
	var land := 1.0 - smoothstep(0.91, 1.055, coast)
	var basin := 7.4 * exp(-pow((x - 236.0) / 66.0, 2.0) - pow((z + 8.0) / 48.0, 2.0))
	var central := 28.0 * exp(-pow((x + 50.0) / 224.0, 2.0) - pow((z + 76.0) / 180.0, 2.0))
	var north := 34.0 * exp(-pow((x - 130.0) / 156.0, 2.0) - pow((z + 284.0) / 116.0, 2.0))
	var west := 18.0 * exp(-pow((x + 350.0) / 124.0, 2.0) - pow((z + 30.0) / 250.0, 2.0))
	var south := 8.0 * exp(-pow((x - 40.0) / 320.0, 2.0) - pow((z - 300.0) / 132.0, 2.0))
	var hills := max(_height_noise.get_noise_2d(x, z), -0.35) * 10.0
	return lerp(SEA_LEVEL - 0.8, 0.7 + central + north + west + south + hills + _detail_noise.get_noise_2d(x, z) * 1.35 - basin, land)


func _create_ocean() -> void:
	var ocean_mesh := PlaneMesh.new()
	ocean_mesh.size = Vector2(3600.0, 3600.0)
	ocean_mesh.subdivide_width = 100
	ocean_mesh.subdivide_depth = 100
	var ocean := MeshInstance3D.new()
	ocean.name = "DeepOcean"
	ocean.mesh = ocean_mesh
	ocean.material_override = _water_material
	ocean.position.y = SEA_LEVEL
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ocean)


func _create_lake() -> void:
	var lake_mesh := PlaneMesh.new()
	lake_mesh.size = Vector2(48.0, 34.0)
	lake_mesh.subdivide_width = 24
	lake_mesh.subdivide_depth = 18
	var lake := MeshInstance3D.new()
	lake.name = "HiddenForestLake"
	lake.mesh = lake_mesh
	lake.material_override = _water_material
	lake.position = Vector3(236.0, _height_at(236.0, -8.0) + 0.35, -8.0)
	lake.rotation_degrees.y = -18.0
	lake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lake)


func _create_river() -> void:
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	const SEGMENTS := 100
	for i in range(SEGMENTS + 1):
		var t := float(i) / float(SEGMENTS)
		var x := lerp(110.0, -330.0, t) + sin(t * PI * 3.0) * 48.0
		var z := lerp(-356.0, 410.0, t)
		var next_t := min(t + 0.008, 1.0)
		var nx := lerp(110.0, -330.0, next_t) + sin(next_t * PI * 3.0) * 48.0
		var nz := lerp(-356.0, 410.0, next_t)
		var tangent := Vector2(nx - x, nz - z).normalized()
		var side := Vector2(-tangent.y, tangent.x)
		var width := lerp(10.4, 3.2, t)
		var y := _height_at(x, z) + 0.12
		left.append(Vector3(x + side.x * width, y, z + side.y * width))
		right.append(Vector3(x - side.x * width, y, z - side.y * width))

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(SEGMENTS + 1):
		surface.set_color(Color(0.72, 0.84, 0.79))
		surface.add_vertex(left[i])
		surface.set_color(Color(0.52, 0.72, 0.69))
		surface.add_vertex(right[i])
	for i in range(SEGMENTS):
		var a := i * 2
		var b := a + 1
		var c := a + 2
		var d := a + 3
		surface.add_index(a)
		surface.add_index(c)
		surface.add_index(b)
		surface.add_index(b)
		surface.add_index(c)
		surface.add_index(d)
	surface.generate_normals()
	var river := MeshInstance3D.new()
	river.name = "WindingFreshwaterRiver"
	river.mesh = surface.commit()
	river.material_override = _river_material
	river.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(river)


func _scatter_conifer_forest() -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.28
	trunk_mesh.bottom_radius = 0.55
	trunk_mesh.height = 13.0
	trunk_mesh.radial_segments = 7

	var low_cone := ConeMesh.new()
	low_cone.bottom_radius = 4.3
	low_cone.top_radius = 0.0
	low_cone.height = 10.5
	low_cone.radial_segments = 7
	var mid_cone := ConeMesh.new()
	mid_cone.bottom_radius = 3.25
	mid_cone.top_radius = 0.0
	mid_cone.height = 9.0
	mid_cone.radial_segments = 7
	var top_cone := ConeMesh.new()
	top_cone.bottom_radius = 2.15
	top_cone.top_radius = 0.0
	top_cone.height = 7.5
	top_cone.radial_segments = 7

	var trunks: Array[Transform3D] = []
	var low: Array[Transform3D] = []
	var middle: Array[Transform3D] = []
	var top: Array[Transform3D] = []

	var attempts := 0
	while trunks.size() < 3500 and attempts < 23000:
		attempts += 1
		var angle := _rng.randf_range(0.0, TAU)
		var radius := sqrt(_rng.randf_range(0.035, 0.91))
		var x := cos(angle) * ISLAND_RX * radius
		var z := sin(angle) * ISLAND_RZ * radius
		var height := _height_at(x, z)
		if height < 2.0 or height > 30.0 or _slope_at(x, z) > 1.35:
			continue
		if _near_river(x, z, 26.0) or _near_lake(x, z, 56.0):
			continue
		if _in_clearing(x, z):
			continue

		var size := _rng.randf_range(0.76, 1.36)
		var rotation := _rng.randf_range(0.0, TAU)
		var base := Vector3(x, height, z)
		trunks.append(_make_transform(base + Vector3.UP * (6.2 * size), rotation, Vector3(0.85 * size, size, 0.85 * size)))
		low.append(_make_transform(base + Vector3.UP * (10.4 * size), rotation, Vector3.ONE * size))
		middle.append(_make_transform(base + Vector3.UP * (14.4 * size), rotation, Vector3.ONE * size))
		top.append(_make_transform(base + Vector3.UP * (18.0 * size), rotation, Vector3.ONE * size))

	_add_multimesh("PineTrunks", trunk_mesh, trunks, _trunk_material)
	_add_multimesh("PineCanopyLower", low_cone, low, _pine_material)
	_add_multimesh("PineCanopyMiddle", mid_cone, middle, _pine_light_material)
	_add_multimesh("PineCanopyUpper", top_cone, top, _pine_material)


func _scatter_broadleaf_trees() -> void:
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.0
	crown_mesh.height = 2.0
	crown_mesh.radial_segments = 9
	crown_mesh.rings = 6
	var crown_material := StandardMaterial3D.new()
	crown_material.albedo_color = Color(0.13, 0.205, 0.105)
	crown_material.roughness = 1.0

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.22
	trunk_mesh.bottom_radius = 0.48
	trunk_mesh.height = 10.0
	trunk_mesh.radial_segments = 7

	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var attempts := 0
	while crowns.size() < 460 and attempts < 4400:
		attempts += 1
		var x := _rng.randf_range(-540.0, 540.0)
		var z := _rng.randf_range(-450.0, 450.0)
		var height := _height_at(x, z)
		if height < 2.0 or height > 16.0 or _slope_at(x, z) > 1.05:
			continue
		if _near_river(x, z, 22.0) or _near_lake(x, z, 44.0) or _in_clearing(x, z):
			continue
		var scale := _rng.randf_range(0.8, 1.35)
		trunks.append(_make_transform(Vector3(x, height + 4.5 * scale, z), 0.0, Vector3.ONE * scale))
		crowns.append(_make_transform(Vector3(x, height + 10.0 * scale, z), 0.0, Vector3(4.2, 3.0, 4.0) * scale))
	_add_multimesh("BroadleafTrunks", trunk_mesh, trunks, _trunk_material)
	_add_multimesh("BroadleafCrowns", crown_mesh, crowns, crown_material)


func _scatter_understory() -> void:
	var bushes: Array[Transform3D] = []
	var grass: Array[Transform3D] = []
	var attempts := 0
	while bushes.size() < 1500 and attempts < 8400:
		attempts += 1
		var x := _rng.randf_range(-580.0, 580.0)
		var z := _rng.randf_range(-490.0, 490.0)
		var height := _height_at(x, z)
		if height < 1.7 or height > 22.0 or _slope_at(x, z) > 1.6:
			continue
		if _near_river(x, z, 16.0) or _near_lake(x, z, 32.0):
			continue
		if _rng.randf() < 0.32:
			var s := _rng.randf_range(0.8, 1.65)
			bushes.append(_make_transform(Vector3(x, height + 0.55 * s, z), _rng.randf_range(0.0, TAU), Vector3(1.3, 0.8, 1.2) * s))
		else:
			var s := _rng.randf_range(0.45, 1.35)
			grass.append(_make_transform(Vector3(x, height + 0.25, z), _rng.randf_range(0.0, TAU), Vector3.ONE * s))
	_add_multimesh("ForestUnderstory", _bush_mesh, bushes, _bush_material)
	var grass_material := StandardMaterial3D.new()
	grass_material.albedo_color = Color(0.21, 0.29, 0.14)
	grass_material.roughness = 1.0
	_add_multimesh("ForestGrassClumps", _grass_mesh, grass, grass_material)


func _scatter_rocks_and_logs() -> void:
	var rocks: Array[Transform3D] = []
	var logs: Array[Transform3D] = []
	for i in range(600):
		var x := _rng.randf_range(-610.0, 610.0)
		var z := _rng.randf_range(-516.0, 516.0)
		var height := _height_at(x, z)
		if height < 0.0 or height > 40.0:
			continue
		var size := _rng.randf_range(0.6, 4.4)
		rocks.append(_make_transform(Vector3(x, height + size * 0.34, z), _rng.randf_range(0.0, TAU), Vector3(size * 1.2, size * 0.7, size)))
		if i < 160 and height > 1.5 and height < 16.0:
			var length := _rng.randf_range(2.0, 7.0)
			logs.append(_make_transform(Vector3(x + 3.0, height + 0.35, z - 2.0), _rng.randf_range(0.0, TAU), Vector3(length, 0.32, 0.38)))

	_add_multimesh("ScatteredBoulders", _rock_mesh, rocks, _rock_material)
	var log_mesh := CylinderMesh.new()
	log_mesh.top_radius = 0.34
	log_mesh.bottom_radius = 0.38
	log_mesh.height = 1.0
	log_mesh.radial_segments = 7
	_add_multimesh("FallenTreeTrunks", log_mesh, logs, _trunk_material)


func _create_cave_system() -> void:
	_create_cave_entrance(Vector3(-244.0, _height_at(-244.0, -150.0), -150.0), "NorthernRidgeCave", 1.0)
	_create_cave_entrance(Vector3(368.0, _height_at(368.0, 96.0), 96.0), "EasternCliffCave", 0.76)


func _create_cave_entrance(location: Vector3, cave_name: String, size: float) -> void:
	var cave := Node3D.new()
	cave.name = cave_name
	cave.position = location
	cave.scale = Vector3.ONE * size
	add_child(cave)

	var darkness := StandardMaterial3D.new()
	darkness.albedo_color = Color(0.006, 0.009, 0.009)
	darkness.roughness = 1.0
	var mouth := MeshInstance3D.new()
	mouth.mesh = SphereMesh.new()
	mouth.material_override = darkness
	mouth.position = Vector3(0.0, 2.8, 0.0)
	mouth.scale = Vector3(5.8, 5.2, 0.48)
	cave.add_child(mouth)

	var arch_mesh := TorusMesh.new()
	arch_mesh.inner_radius = 4.8
	arch_mesh.outer_radius = 5.7
	arch_mesh.rings = 20
	arch_mesh.ring_segments = 8
	var arch := MeshInstance3D.new()
	arch.mesh = arch_mesh
	arch.material_override = _rock_material
	arch.rotation_degrees.x = 90.0
	arch.position.y = 2.8
	cave.add_child(arch)


func _create_coastal_camp() -> void:
	var camp := Node3D.new()
	camp.name = "AbandonedCoastalCamp"
	var x := -416.0
	var z := 304.0
	camp.position = Vector3(x, _height_at(x, z) + 0.08, z)
	add_child(camp)

	var canvas := StandardMaterial3D.new()
	canvas.albedo_color = Color(0.29, 0.25, 0.17)
	canvas.roughness = 1.0
	var tent := MeshInstance3D.new()
	var tent_mesh := PrismMesh.new()
	tent_mesh.size = Vector3(8.0, 4.4, 5.0)
	tent.mesh = tent_mesh
	tent.material_override = canvas
	tent.position = Vector3(0.0, 2.2, 0.0)
	camp.add_child(tent)

	var fire_base := MeshInstance3D.new()
	var fire_mesh := CylinderMesh.new()
	fire_mesh.top_radius = 0.85
	fire_mesh.bottom_radius = 1.0
	fire_mesh.height = 0.22
	fire_mesh.radial_segments = 8
	fire_base.mesh = fire_mesh
	fire_base.material_override = _rock_material
	fire_base.position = Vector3(7.0, 0.14, 1.0)
	camp.add_child(fire_base)

	var fire_light := OmniLight3D.new()
	fire_light.light_color = Color(1.0, 0.43, 0.16)
	fire_light.light_energy = 0.65
	fire_light.omni_range = 15.0
	fire_light.position = Vector3(7.0, 1.5, 1.0)
	camp.add_child(fire_light)



func _create_plane_wreck() -> void:
	var wreck := Node3D.new()
	wreck.name = "WreckedIslandAircraft"
	var x := -500.0
	var z := 192.0
	wreck.position = Vector3(x, _height_at(x, z) + 1.1, z)
	wreck.rotation.y = 0.42
	add_child(wreck)

	var faded_metal := StandardMaterial3D.new()
	faded_metal.albedo_color = Color(0.34, 0.32, 0.27)
	faded_metal.metallic = 0.42
	faded_metal.roughness = 0.88
	var dark_metal := StandardMaterial3D.new()
	dark_metal.albedo_color = Color(0.12, 0.15, 0.14)
	dark_metal.metallic = 0.35
	dark_metal.roughness = 0.92
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.075, 0.14, 0.15, 0.72)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.22

	var fuselage_mesh := CylinderMesh.new()
	fuselage_mesh.top_radius = 1.12
	fuselage_mesh.bottom_radius = 1.12
	fuselage_mesh.height = 22.0
	fuselage_mesh.radial_segments = 12
	var fuselage := MeshInstance3D.new()
	fuselage.mesh = fuselage_mesh
	fuselage.material_override = faded_metal
	fuselage.rotation_degrees.z = 90.0
	fuselage.position.y = 1.3
	wreck.add_child(fuselage)

	_add_box(wreck, Vector3(0.0, 1.4, 0.0), Vector3(3.0, 0.45, 25.0), dark_metal)
	_add_box(wreck, Vector3(-1.0, 1.2, -9.0), Vector3(2.0, 0.22, 13.0), faded_metal)
	_add_box(wreck, Vector3(-1.0, 1.2, 9.0), Vector3(2.0, 0.22, 8.0), faded_metal)
	_add_box(wreck, Vector3(0.0, 4.1, -9.2), Vector3(0.55, 5.4, 2.2), faded_metal)
	_add_box(wreck, Vector3(0.0, 2.8, 10.2), Vector3(0.5, 2.8, 3.8), dark_metal)
	_add_box(wreck, Vector3(0.0, 2.5, -4.2), Vector3(2.3, 1.4, 0.22), glass)
	_add_box(wreck, Vector3(0.0, 2.5, -1.4), Vector3(2.3, 1.4, 0.22), glass)


func _create_swamp_region() -> void:
	var swamp := Node3D.new()
	swamp.name = "MistyLowlandSwamp"
	add_child(swamp)
	var mud := StandardMaterial3D.new()
	mud.albedo_color = Color(0.105, 0.13, 0.095)
	mud.roughness = 1.0
	var pool_material := StandardMaterial3D.new()
	pool_material.albedo_color = Color(0.025, 0.105, 0.095)
	pool_material.roughness = 0.24

	var center := Vector2(420.0, 310.0)
	for i in range(7):
		var offset := Vector2(_rng.randf_range(-56.0, 56.0), _rng.randf_range(-44.0, 44.0))
		var point := center + offset
		var ground := _height_at(point.x, point.y)
		var pool_mesh := PlaneMesh.new()
		pool_mesh.size = Vector2(_rng.randf_range(18.0, 38.0), _rng.randf_range(14.0, 30.0))
		var pool := MeshInstance3D.new()
		pool.mesh = pool_mesh
		pool.material_override = pool_material
		pool.position = Vector3(point.x, ground + 0.14, point.y)
		pool.rotation_degrees.y = _rng.randf_range(-25.0, 25.0)
		pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		swamp.add_child(pool)

	var dead_wood := StandardMaterial3D.new()
	dead_wood.albedo_color = Color(0.19, 0.17, 0.13)
	dead_wood.roughness = 1.0
	var dead_trunk_mesh := CylinderMesh.new()
	dead_trunk_mesh.top_radius = 0.13
	dead_trunk_mesh.bottom_radius = 0.42
	dead_trunk_mesh.height = 9.0
	dead_trunk_mesh.radial_segments = 6
	for i in range(52):
		var x := center.x + _rng.randf_range(-96.0, 96.0)
		var z := center.y + _rng.randf_range(-76.0, 76.0)
		var ground := _height_at(x, z)
		var dead_tree := MeshInstance3D.new()
		dead_tree.mesh = dead_trunk_mesh
		dead_tree.material_override = dead_wood
		dead_tree.position = Vector3(x, ground + 4.3, z)
		dead_tree.rotation_degrees.z = _rng.randf_range(-13.0, 13.0)
		dead_tree.rotation_degrees.x = _rng.randf_range(-10.0, 10.0)
		swamp.add_child(dead_tree)

	var mist_shader := Shader.new()
	mist_shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
void fragment() {
	float edge_x = smoothstep(0.0, 0.2, UV.x) * (1.0 - smoothstep(0.8, 1.0, UV.x));
	float edge_y = smoothstep(0.0, 0.25, UV.y) * (1.0 - smoothstep(0.75, 1.0, UV.y));
	float drift = 0.75 + 0.25 * sin(TIME * 0.35 + UV.x * 8.0);
	ALBEDO = vec3(0.48, 0.55, 0.47);
	ALPHA = edge_x * edge_y * drift * 0.17;
}
"""
	var mist_material := ShaderMaterial.new()
	mist_material.shader = mist_shader
	var mist_mesh := PlaneMesh.new()
	mist_mesh.size = Vector2(94.0, 76.0)
	var mist := MeshInstance3D.new()
	mist.name = "LowSwampMist"
	mist.mesh = mist_mesh
	mist.material_override = mist_material
	mist.position = Vector3(center.x, _height_at(center.x, center.y) + 1.8, center.y)
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	swamp.add_child(mist)

func _create_abandoned_research_site() -> void:
	var site := Node3D.new()
	site.name = "AbandonedForestResearchSite"
	var x := 328.0
	var z := -244.0
	site.position = Vector3(x, _height_at(x, z), z)
	site.rotation.y = -0.32
	add_child(site)

	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.20, 0.23, 0.22)
	metal.metallic = 0.52
	metal.roughness = 0.72
	var wall := StandardMaterial3D.new()
	wall.albedo_color = Color(0.29, 0.30, 0.26)
	wall.roughness = 0.95

	_add_box(site, Vector3(0.0, 2.0, 0.0), Vector3(13.0, 4.0, 9.0), wall)
	_add_box(site, Vector3(0.0, 4.15, 0.0), Vector3(14.0, 0.45, 10.0), metal)
	_add_box(site, Vector3(6.65, 1.3, 0.0), Vector3(0.3, 2.6, 2.2), metal)
	_add_box(site, Vector3(-8.0, 1.35, 4.65), Vector3(2.5, 2.2, 0.18), metal)

	var mast := MeshInstance3D.new()
	var mast_mesh := CylinderMesh.new()
	mast_mesh.top_radius = 0.12
	mast_mesh.bottom_radius = 0.18
	mast_mesh.height = 16.0
	mast.mesh = mast_mesh
	mast.material_override = metal
	mast.position = Vector3(-7.0, 8.0, -8.0)
	site.add_child(mast)


func _create_trails() -> void:
	_create_trail_segment(Vector3(-416.0, 0.0, 304.0), Vector3(-160.0, 0.0, 116.0), 6.0)
	_create_trail_segment(Vector3(-160.0, 0.0, 116.0), Vector3(80.0, 0.0, -56.0), 4.8)
	_create_trail_segment(Vector3(80.0, 0.0, -56.0), Vector3(328.0, 0.0, -244.0), 4.4)


func _create_trail_segment(start: Vector3, finish: Vector3, width: float) -> void:
	var points: Array[Vector3] = []
	const SEGMENTS := 28
	for i in range(SEGMENTS + 1):
		var t := float(i) / float(SEGMENTS)
		var point := start.lerp(finish, t)
		point.y = _height_at(point.x, point.z) + 0.09
		points.append(point)

	var vertices: Array[Vector3] = []
	for i in range(points.size()):
		var previous := points[max(i - 1, 0)]
		var next := points[min(i + 1, points.size() - 1)]
		var tangent := Vector2(next.x - previous.x, next.z - previous.z).normalized()
		var side := Vector2(-tangent.y, tangent.x) * width
		vertices.append(points[i] + Vector3(side.x, 0.0, side.y))
		vertices.append(points[i] - Vector3(side.x, 0.0, side.y))

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in vertices:
		surface.set_color(Color(0.22, 0.19, 0.13))
		surface.add_vertex(vertex)
	for i in range(SEGMENTS):
		var a := i * 2
		surface.add_index(a)
		surface.add_index(a + 2)
		surface.add_index(a + 1)
		surface.add_index(a + 1)
		surface.add_index(a + 2)
		surface.add_index(a + 3)
	surface.generate_normals()
	var trail := MeshInstance3D.new()
	trail.mesh = surface.commit()
	var trail_material := StandardMaterial3D.new()
	trail_material.albedo_color = Color(0.24, 0.21, 0.15)
	trail_material.roughness = 1.0
	trail.material_override = trail_material
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trail)


func _create_showcase_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "TemporaryIslandOverviewCamera"
	_camera.fov = 54.0
	_camera.near = 0.2
	_camera.far = 1500.0
	add_child(_camera)
	_camera.position = Vector3(720.0, 504.0, 680.0)
	_camera.look_at(Vector3(0.0, 8.0, 0.0), Vector3.UP)
	_camera.current = true


func _add_multimesh(label: String, mesh: Mesh, transforms: Array[Transform3D], material: Material) -> void:
	if transforms.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in range(transforms.size()):
		multimesh.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _make_transform(position: Vector3, rotation: float, scale: Vector3) -> Transform3D:
	var basis := Basis(Vector3.UP, rotation).scaled(scale)
	return Transform3D(basis, position)


func _add_box(parent: Node3D, position: Vector3, size: Vector3, material: Material) -> void:
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	box.mesh = mesh
	box.material_override = material
	box.position = position
	box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(box)


func _near_river(x: float, z: float, radius: float) -> bool:
	var t := clamp((z + 356.0) / 766.0, 0.0, 1.0)
	var river_x := lerp(110.0, -330.0, t) + sin(t * PI * 3.0) * 48.0
	return Vector2(x - river_x, 0.0).length() < radius


func _near_lake(x: float, z: float, radius: float) -> bool:
	var lake_center := Vector2(236.0, -8.0)
	var point := Vector2(x, z)
	return (point - lake_center).length() < radius


func _in_clearing(x: float, z: float) -> bool:
	var camp := Vector2(-416.0, 304.0)
	var research := Vector2(328.0, -244.0)
	return Vector2(x, z).distance_to(camp) < 38.0 or Vector2(x, z).distance_to(research) < 48.0
