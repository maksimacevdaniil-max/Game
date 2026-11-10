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
var _sun: DirectionalLight3D
var _world_environment: Environment
var _sky_material: ProceduralSkyMaterial
var _day_clock := 0.25
var _orbit_time := 0.0

var _terrain_material: ShaderMaterial
var _sand_material: StandardMaterial3D
var _rock_material: ShaderMaterial
var _trunk_material: ShaderMaterial
var _pine_material: ShaderMaterial
var _pine_light_material: ShaderMaterial
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
	_create_coastal_sea_stacks()
	_create_lake()
	_create_western_tarn()
	_create_western_tarn_shoreline()
	_create_western_tarn_grove()
	_create_river()
	_create_riverbank_woodland()
	_scatter_conifer_forest()
	_scatter_broadleaf_trees()
	_scatter_understory()
	_scatter_rocks_and_logs()
	_create_coastal_and_mountain_details()
	_create_beach_tide_pools_and_driftwood()
	_create_coastal_dune_grass()
	_create_mountain_streams_and_waterfalls()
	_create_waterfall_basin_details()
	_create_stream_bank_gravel()
	_create_cave_system()
	_create_coastal_camp()
	_create_plane_wreck()
	_create_player_spawn_marker()
	_create_swamp_region()
	_create_swamp_water_channels()
	_create_swamp_surface_details()
	_create_biome_groundcover()
	_create_ravine_boulder_fields()
	_create_natural_rock_arches()
	_create_highland_meadow_details()
	_create_cliff_outcrops()
	_create_northern_ridge_spires()
	_create_highland_deadwood()
	_create_abandoned_research_site()
	_create_trails()
	_create_river_bridge()
	_create_forest_lookout()
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
	_advance_day_cycle(delta)


func _advance_day_cycle(delta: float) -> void:
	_day_clock = fposmod(_day_clock + delta * 0.0011, 1.0)
	var daylight: float = maxf(sin(TAU * _day_clock), 0.0)
	if is_instance_valid(_sun):
		_sun.rotation_degrees.x = -90.0 - cos(TAU * _day_clock) * 80.0
		_sun.light_energy = lerp(0.025, 1.22, daylight)
		_sun.light_color = Color(0.24, 0.34, 0.49).lerp(Color(1.0, 0.89, 0.75), daylight)
	if _world_environment != null:
		_world_environment.ambient_light_energy = lerp(0.13, 0.72, daylight)
		_world_environment.fog_density = lerp(0.0032, 0.0016, daylight)
	if _sky_material != null:
		_sky_material.sky_top_color = Color(0.012, 0.024, 0.052).lerp(Color(0.105, 0.19, 0.25), daylight)
		_sky_material.sky_horizon_color = Color(0.075, 0.10, 0.14).lerp(Color(0.52, 0.59, 0.57), daylight)
		_sky_material.ground_horizon_color = Color(0.045, 0.06, 0.07).lerp(Color(0.31, 0.37, 0.32), daylight)


func _create_materials() -> void:
	var terrain_shader := Shader.new()
	terrain_shader.code = """
shader_type spatial;
varying vec3 world_position;
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += noise2d(p) * amplitude;
		p *= 2.03;
		amplitude *= 0.5;
	}
	return value;
}
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float grain = fbm(world_position.xz * 0.22);
	float fine_grain = noise2d(world_position.xz * 1.6);
	vec3 base = COLOR.rgb;
	base *= 0.82 + grain * 0.34;
	base = mix(base, base * vec3(0.66, 0.73, 0.59), smoothstep(0.67, 0.92, fine_grain) * 0.22);
	ALBEDO = base;
	ROUGHNESS = 0.98;
}
"""
	_terrain_material = ShaderMaterial.new()
	_terrain_material.shader = terrain_shader

	_sand_material = StandardMaterial3D.new()
	_sand_material.albedo_color = Color(0.42, 0.37, 0.29)
	_sand_material.roughness = 0.98

	_rock_material = _make_rock_material(Color(0.27, 0.29, 0.28))
	_trunk_material = _make_bark_material(Color(0.22, 0.16, 0.12))

	_pine_material = _make_pine_material(Color(0.045, 0.16, 0.105))
	_pine_light_material = _make_pine_material(Color(0.075, 0.205, 0.125))

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




func _make_bark_material(tint: Color) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
uniform vec4 bark_tint : source_color = vec4(0.22, 0.16, 0.12, 1.0);
varying vec3 local_position;
varying vec3 object_origin;
float bark_noise(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
void vertex() {
	local_position = VERTEX;
	object_origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
}
void fragment() {
	float grooves = sin(local_position.y * 21.0 + sin(local_position.x * 8.0 + local_position.z * 7.0) * 1.8);
	float flecks = bark_noise(floor((local_position.xz + object_origin.xz) * 8.0));
	float grain = 0.82 + grooves * 0.075 + flecks * 0.12;
	ALBEDO = bark_tint.rgb * grain;
	ROUGHNESS = 0.99;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("bark_tint", tint)
	return material


func _make_rock_material(tint: Color) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
uniform vec4 stone_tint : source_color = vec4(0.27, 0.29, 0.28, 1.0);
varying vec3 local_position;
varying vec3 object_origin;
float stone_hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
void vertex() {
	local_position = VERTEX;
	object_origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
}
void fragment() {
	float broad = stone_hash(floor((local_position + object_origin) * 2.5));
	float fine = stone_hash(floor((local_position + object_origin) * 14.0));
	float striation = sin(local_position.y * 5.0 + local_position.x * 2.0) * 0.045;
	float variation = 0.78 + broad * 0.2 + fine * 0.12 + striation;
	ALBEDO = stone_tint.rgb * variation;
	ROUGHNESS = 0.96;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("stone_tint", tint)
	return material


func _make_pine_material(tint: Color) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color = vec4(0.05, 0.16, 0.10, 1.0);
varying vec3 tree_origin;
void vertex() {
	tree_origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float canopy_mask = clamp((VERTEX.y + 5.0) / 10.0, 0.0, 1.0);
	float wind_a = sin(TIME * 0.82 + tree_origin.x * 0.018 + tree_origin.z * 0.021 + VERTEX.y * 0.18);
	float wind_b = cos(TIME * 0.64 + tree_origin.z * 0.025 + VERTEX.y * 0.13);
	VERTEX.x += wind_a * 0.17 * canopy_mask;
	VERTEX.z += wind_b * 0.10 * canopy_mask;
}
void fragment() {
	float variation = 0.91 + 0.09 * sin(tree_origin.x * 0.08 + tree_origin.z * 0.07);
	ALBEDO = tint.rgb * variation;
	ROUGHNESS = 0.97;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("tint", tint)
	return material


func _create_atmosphere() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	_sky_material = sky_material
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
	_world_environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "OvercastForestSun"
	sun.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	sun.light_color = Color(0.79, 0.84, 0.78)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 230.0
	_sun = sun
	add_child(sun)


func _create_terrain() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	for z_index in range(GRID_Z + 1):
		var z := -WORLD_Z + (float(z_index) / float(GRID_Z)) * WORLD_Z * 2.0
		for x_index in range(GRID_X + 1):
			var x := -WORLD_X + (float(x_index) / float(GRID_X)) * WORLD_X * 2.0
			var height := _height_at(x, z)
			var slope := _slope_at(x, z)
			surface.set_color(_terrain_color(x, z, height, slope))
			surface.add_vertex(Vector3(x, height, z))

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
	var eastern_peak := 28.0 * exp(-pow((x - 270.0) / 90.0, 2.0) - pow((z + 330.0) / 78.0, 2.0))
	var west_ridge := 18.0 * exp(-pow((x + 350.0) / 124.0, 2.0) - pow((z + 30.0) / 250.0, 2.0))
	var southern_hills := 8.0 * exp(-pow((x - 40.0) / 320.0, 2.0) - pow((z - 300.0) / 132.0, 2.0))
	var broad_hills: float = maxf(_height_noise.get_noise_2d(x, z), -0.35) * 10.0
	var fine_detail := _detail_noise.get_noise_2d(x, z) * 1.35
	var elevation: float = 0.7 + central_ridge + north_peak + eastern_peak + west_ridge + southern_hills + broad_hills + fine_detail - lake_basin - _ravine_cut_at(x, z) - _western_tarn_basin_at(x, z)
	return lerp(SEA_LEVEL - 0.8, elevation, land)


func _terrain_color(x: float, z: float, height: float, slope: float) -> Color:
	var grass := Color(0.15, 0.235, 0.145)
	var dark_grass := Color(0.075, 0.145, 0.095)
	var moss := Color(0.23, 0.265, 0.16)
	var sand := Color(0.43, 0.365, 0.265)
	var stone := Color(0.31, 0.325, 0.31)
	var high_stone := Color(0.235, 0.255, 0.25)

	if height < 2.1:
		var beach_mix: float = clampf((height + 1.4) / 3.5, 0.0, 1.0)
		return sand.lerp(grass, beach_mix)
	var color := dark_grass.lerp(grass, clamp((height - 2.0) / 12.0, 0.0, 1.0))
	if height > 16.0 or slope > 1.75:
		color = color.lerp(stone, clamp(max((height - 16.0) / 18.0, (slope - 1.4) / 2.2), 0.0, 0.92))
	if height > 31.0:
		color = color.lerp(high_stone, clamp((height - 31.0) / 15.0, 0.0, 0.75))
	var moss_factor := _detail_noise.get_noise_2d(x * 2.0, z * 2.0) * 0.055
	var final_color := Color(
		clamp(color.r + moss_factor, 0.0, 1.0),
		clamp(color.g + moss_factor, 0.0, 1.0),
		clamp(color.b + moss_factor, 0.0, 1.0)
	)
	var swamp_distance := Vector2(x - 420.0, z - 310.0).length()
	var wetland_mask := (1.0 - smoothstep(72.0, 178.0, swamp_distance)) * (1.0 - smoothstep(5.0, 11.0, height))
	var wet_mud := Color(0.075, 0.105, 0.075)
	final_color = final_color.lerp(wet_mud, wetland_mask * 0.78)
	var ravine_center_x := -82.0 + sin(z * 0.0085) * 52.0
	var ravine_distance: float = absf(x - ravine_center_x)
	var ravine_mask := (1.0 - smoothstep(15.0, 48.0, ravine_distance)) * (1.0 - smoothstep(18.0, 34.0, height))
	final_color = final_color.lerp(Color(0.22, 0.235, 0.22), ravine_mask * 0.62)
	return final_color


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
	var east := 28.0 * exp(-pow((x - 270.0) / 90.0, 2.0) - pow((z + 330.0) / 78.0, 2.0))
	var west := 18.0 * exp(-pow((x + 350.0) / 124.0, 2.0) - pow((z + 30.0) / 250.0, 2.0))
	var south := 8.0 * exp(-pow((x - 40.0) / 320.0, 2.0) - pow((z - 300.0) / 132.0, 2.0))
	var hills: float = maxf(_height_noise.get_noise_2d(x, z), -0.35) * 10.0
	return lerp(SEA_LEVEL - 0.8, 0.7 + central + north + east + west + south + hills + _detail_noise.get_noise_2d(x, z) * 1.35 - basin - _ravine_cut_at(x, z) - _western_tarn_basin_at(x, z), land)



func _ravine_cut_at(x: float, z: float) -> float:
	# A winding erosion channel through the highlands creates a readable
	# valley floor and steeper shoulders without breaking terrain continuity.
	var ravine_center_x := -82.0 + sin(z * 0.0085) * 52.0
	var north_gate := smoothstep(-350.0, -275.0, z)
	var south_gate := 1.0 - smoothstep(170.0, 265.0, z)
	var channel := exp(-pow((x - ravine_center_x) / 31.0, 2.0))
	return 8.8 * channel * north_gate * south_gate


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
	lake_mesh.size = Vector2(96.0, 68.0)
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
		var x: float = lerpf(110.0, -330.0, t) + sin(t * PI * 3.0) * 48.0
		var z: float = lerpf(-356.0, 410.0, t)
		var next_t: float = minf(t + 0.008, 1.0)
		var nx: float = lerpf(110.0, -330.0, next_t) + sin(next_t * PI * 3.0) * 48.0
		var nz: float = lerpf(-356.0, 410.0, next_t)
		var tangent := Vector2(nx - x, nz - z).normalized()
		var side := Vector2(-tangent.y, tangent.x)
		var width: float = lerpf(10.4, 3.2, t)
		var y: float = _height_at(x, z) + 0.12
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

	var low_cone := CylinderMesh.new()
	low_cone.bottom_radius = 4.3
	low_cone.top_radius = 0.0
	low_cone.height = 10.5
	low_cone.radial_segments = 7
	var mid_cone := CylinderMesh.new()
	mid_cone.bottom_radius = 3.25
	mid_cone.top_radius = 0.0
	mid_cone.height = 9.0
	mid_cone.radial_segments = 7
	var top_cone := CylinderMesh.new()
	top_cone.bottom_radius = 2.15
	top_cone.top_radius = 0.0
	top_cone.height = 7.5
	top_cone.radial_segments = 7

	var trunks: Array[Transform3D] = []
	var low: Array[Transform3D] = []
	var middle: Array[Transform3D] = []
	var top: Array[Transform3D] = []

	var attempts := 0
	while trunks.size() < 8500 and attempts < 55000:
		attempts += 1
		var angle := _rng.randf_range(0.0, TAU)
		var radius := sqrt(_rng.randf_range(0.035, 0.91))
		var x := cos(angle) * ISLAND_RX * radius
		var z := sin(angle) * ISLAND_RZ * radius
		var height := _height_at(x, z)
		if height < 2.0 or height > 30.0 or _slope_at(x, z) > 1.35:
			continue
		if _near_river(x, z, 44.0) or _near_lake(x, z, 56.0):
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
	while crowns.size() < 900 and attempts < 8500:
		attempts += 1
		var x := _rng.randf_range(-540.0, 540.0)
		var z := _rng.randf_range(-450.0, 450.0)
		var height := _height_at(x, z)
		if height < 2.0 or height > 16.0 or _slope_at(x, z) > 1.05:
			continue
		if _near_river(x, z, 40.0) or _near_lake(x, z, 44.0) or _in_clearing(x, z):
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
	while bushes.size() < 2600 and attempts < 14500:
		attempts += 1
		var x := _rng.randf_range(-580.0, 580.0)
		var z := _rng.randf_range(-490.0, 490.0)
		var height := _height_at(x, z)
		if height < 1.7 or height > 22.0 or _slope_at(x, z) > 1.6:
			continue
		if _near_river(x, z, 34.0) or _near_lake(x, z, 32.0):
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
	_create_cave_entrance(Vector3(-350.0, _height_at(-350.0, 0.0), 0.0), "EasternCliffCave", 0.76)


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

	# Broken rock lips and hanging stone teeth make the cave mouth read as
	# a natural opening rather than a flat black portal.
	var cave_rock_mesh := SphereMesh.new()
	cave_rock_mesh.radius = 1.0
	cave_rock_mesh.height = 2.0
	cave_rock_mesh.radial_segments = 8
	cave_rock_mesh.rings = 5
	for i in range(7):
		var angle := PI * float(i) / 6.0
		var rock := MeshInstance3D.new()
		rock.name = "CaveMouthBrokenRock_%02d" % i
		rock.mesh = cave_rock_mesh
		rock.material_override = _rock_material
		rock.position = Vector3(cos(angle) * 6.2, 1.1 + sin(angle) * 4.7, 0.12)
		rock.scale = Vector3(_rng.randf_range(1.0, 1.8), _rng.randf_range(0.9, 1.7), 1.0)
		cave.add_child(rock)

	for i in range(4):
		var tooth := MeshInstance3D.new()
		tooth.name = "CaveCeilingStalactite_%02d" % i
		var tooth_mesh := CylinderMesh.new()
		tooth_mesh.top_radius = 0.04
		tooth_mesh.bottom_radius = _rng.randf_range(0.24, 0.48)
		tooth_mesh.height = _rng.randf_range(1.2, 2.8)
		tooth_mesh.radial_segments = 5
		tooth.mesh = tooth_mesh
		tooth.material_override = _rock_material
		tooth.position = Vector3(_rng.randf_range(-3.7, 3.7), 7.1, -0.35)
		cave.add_child(tooth)

	var cave_floor := MeshInstance3D.new()
	cave_floor.name = "CaveShadowedFloor"
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 4.2
	floor_mesh.bottom_radius = 4.2
	floor_mesh.height = 0.16
	floor_mesh.radial_segments = 12
	cave_floor.mesh = floor_mesh
	cave_floor.material_override = darkness
	cave_floor.position = Vector3(0.0, -0.05, -1.8)
	cave.add_child(cave_floor)


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



func _create_player_spawn_marker() -> void:
	var spawn := Marker3D.new()
	spawn.name = "PlayerSpawnPoint"
	spawn.position = Vector3(-490.0, _height_at(-490.0, 220.0) + 1.0, 220.0)
	spawn.add_to_group("player_spawn")
	add_child(spawn)


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
	mist_mesh.size = Vector2(188.0, 152.0)
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
	# Main route from the southern camp through the central forest to the
	# abandoned research station.
	_create_trail_segment(Vector3(-416.0, 0.0, 304.0), Vector3(-160.0, 0.0, 116.0), 6.0)
	_create_trail_segment(Vector3(-160.0, 0.0, 116.0), Vector3(80.0, 0.0, -56.0), 4.8)
	_create_trail_segment(Vector3(80.0, 0.0, -56.0), Vector3(328.0, 0.0, -244.0), 4.4)

	# Shorter branches connect the crash site, bridge, caves, lookout,
	# western tarn and the eastern wetland into one walkable island network.
	_create_trail_route(PackedVector3Array([
		Vector3(-500.0, 0.0, 192.0),
		Vector3(-462.0, 0.0, 246.0),
		Vector3(-416.0, 0.0, 304.0)
	]), 2.8)
	_create_trail_route(PackedVector3Array([
		Vector3(-416.0, 0.0, 304.0),
		Vector3(-318.0, 0.0, 267.0),
		Vector3(-246.0, 0.0, 235.0),
		Vector3(-186.0, 0.0, 217.0)
	]), 3.2)
	_create_trail_route(PackedVector3Array([
		Vector3(-186.0, 0.0, 217.0),
		Vector3(-238.0, 0.0, 202.0),
		Vector3(-300.0, 0.0, 180.0)
	]), 2.7)
	_create_trail_route(PackedVector3Array([
		Vector3(-300.0, 0.0, 180.0),
		Vector3(-326.0, 0.0, 98.0),
		Vector3(-350.0, 0.0, 0.0)
	]), 2.5)
	_create_trail_route(PackedVector3Array([
		Vector3(80.0, 0.0, -56.0),
		Vector3(106.0, 0.0, -132.0),
		Vector3(122.0, 0.0, -212.0),
		Vector3(130.0, 0.0, -284.0)
	]), 2.8)
	_create_trail_route(PackedVector3Array([
		Vector3(130.0, 0.0, -284.0),
		Vector3(204.0, 0.0, -274.0),
		Vector3(268.0, 0.0, -258.0),
		Vector3(328.0, 0.0, -244.0)
	]), 2.7)
	_create_trail_route(PackedVector3Array([
		Vector3(328.0, 0.0, -244.0),
		Vector3(366.0, 0.0, -74.0),
		Vector3(398.0, 0.0, 112.0),
		Vector3(420.0, 0.0, 310.0)
	]), 2.6)
	_create_trail_route(PackedVector3Array([
		Vector3(80.0, 0.0, -56.0),
		Vector3(-26.0, 0.0, -86.0),
		Vector3(-138.0, 0.0, -121.0),
		Vector3(-244.0, 0.0, -150.0)
	]), 2.5)


func _create_trail_route(points: PackedVector3Array, width: float) -> void:
	if points.size() < 2:
		return
	for i in range(points.size() - 1):
		_create_trail_segment(points[i], points[i + 1], width)


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



func _create_river_bridge() -> void:
	var bridge := Node3D.new()
	bridge.name = "OldTimberRiverBridge"
	var x := -186.0
	var z := 217.0
	bridge.position = Vector3(x, _height_at(x, z) + 2.4, z)
	bridge.rotation.y = -0.16
	add_child(bridge)

	var aged_wood := StandardMaterial3D.new()
	aged_wood.albedo_color = Color(0.23, 0.17, 0.11)
	aged_wood.roughness = 0.98
	var dark_wood := StandardMaterial3D.new()
	dark_wood.albedo_color = Color(0.12, 0.105, 0.075)
	dark_wood.roughness = 1.0

	for i in range(13):
		var plank_x := -12.0 + float(i) * 2.0
		_add_box(bridge, Vector3(plank_x, 0.0, 0.0), Vector3(1.9, 0.42, 8.0), aged_wood)

	for side in [-1.0, 1.0]:
		for post_x in [-13.0, -6.5, 0.0, 6.5, 13.0]:
			_add_box(bridge, Vector3(post_x, 1.35, side * 3.7), Vector3(0.42, 2.7, 0.42), dark_wood)
		_add_box(bridge, Vector3(0.0, 2.45, side * 3.7), Vector3(28.0, 0.42, 0.42), aged_wood)

	var support_mesh := CylinderMesh.new()
	support_mesh.top_radius = 0.42
	support_mesh.bottom_radius = 0.58
	support_mesh.height = 5.5
	support_mesh.radial_segments = 7
	for side in [-1.0, 1.0]:
		var support := MeshInstance3D.new()
		support.mesh = support_mesh
		support.material_override = dark_wood
		support.position = Vector3(0.0, -2.2, side * 2.8)
		bridge.add_child(support)


func _create_forest_lookout() -> void:
	var lookout := Node3D.new()
	lookout.name = "RidgeLookoutPlatform"
	var x := 130.0
	var z := -284.0
	lookout.position = Vector3(x, _height_at(x, z), z)
	lookout.rotation.y = 0.35
	add_child(lookout)

	var timber := StandardMaterial3D.new()
	timber.albedo_color = Color(0.24, 0.17, 0.11)
	timber.roughness = 1.0
	var roof_material := StandardMaterial3D.new()
	roof_material.albedo_color = Color(0.17, 0.18, 0.15)
	roof_material.roughness = 0.96

	for px in [-2.6, 2.6]:
		for pz in [-2.6, 2.6]:
			_add_box(lookout, Vector3(px, 4.0, pz), Vector3(0.42, 8.0, 0.42), timber)
	_add_box(lookout, Vector3(0.0, 7.8, 0.0), Vector3(7.0, 0.55, 7.0), timber)
	_add_box(lookout, Vector3(0.0, 10.0, -0.2), Vector3(7.8, 0.42, 7.8), roof_material)
	for side in [-1.0, 1.0]:
		_add_box(lookout, Vector3(0.0, 8.8, side * 3.25), Vector3(6.5, 0.35, 0.3), timber)
		_add_box(lookout, Vector3(side * 3.25, 8.8, 0.0), Vector3(0.3, 0.35, 6.5), timber)

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
	var t: float = clampf((z + 356.0) / 766.0, 0.0, 1.0)
	var river_x: float = lerpf(110.0, -330.0, t) + sin(t * PI * 3.0) * 48.0
	return Vector2(x - river_x, 0.0).length() < radius


func _near_lake(x: float, z: float, radius: float) -> bool:
	var hidden_lake_center := Vector2(236.0, -8.0)
	var western_tarn_center := Vector2(-300.0, 180.0)
	var point := Vector2(x, z)
	return (point - hidden_lake_center).length() < radius or (point - western_tarn_center).length() < radius


func _in_clearing(x: float, z: float) -> bool:
	var camp := Vector2(-416.0, 304.0)
	var research := Vector2(328.0, -244.0)
	var crash_site := Vector2(-500.0, 192.0)
	var swamp := Vector2(420.0, 310.0)
	var lookout := Vector2(130.0, -284.0)
	var bridge := Vector2(-186.0, 217.0)
	var cave_north := Vector2(-244.0, -150.0)
	var cave_west := Vector2(-350.0, 0.0)
	var north_arch := Vector2(-292.0, -250.0)
	var east_arch := Vector2(278.0, 126.0)
	var point := Vector2(x, z)
	return point.distance_to(camp) < 38.0 or point.distance_to(research) < 48.0 or point.distance_to(crash_site) < 58.0 or point.distance_to(swamp) < 100.0 or point.distance_to(lookout) < 25.0 or point.distance_to(bridge) < 24.0 or point.distance_to(cave_north) < 34.0 or point.distance_to(cave_west) < 32.0 or point.distance_to(north_arch) < 34.0 or point.distance_to(east_arch) < 34.0



func _create_coastal_and_mountain_details() -> void:
	# Break up the island's silhouette with layered rock shelves and scattered
	# boulders. All placements are deterministic and use the shared MultiMesh.
	var shoreline_rocks: Array[Transform3D] = []
	var ridge_rocks: Array[Transform3D] = []
	var scree: Array[Transform3D] = []

	for i in range(520):
		var angle := _rng.randf_range(0.0, TAU)
		var radial := _rng.randf_range(0.865, 1.035)
		var x := cos(angle) * ISLAND_RX * radial
		var z := sin(angle) * ISLAND_RZ * radial
		var ground := _height_at(x, z)
		if ground < SEA_LEVEL - 0.4 or ground > 15.0:
			continue
		var size := _rng.randf_range(1.2, 7.2)
		var stretch := _rng.randf_range(0.8, 1.9)
		shoreline_rocks.append(_make_transform(
			Vector3(x, ground + size * 0.28, z),
			_rng.randf_range(0.0, TAU),
			Vector3(size * stretch, size * 0.72, size)
		))

	var attempts := 0
	while ridge_rocks.size() < 310 and attempts < 5200:
		attempts += 1
		var x := _rng.randf_range(-520.0, 520.0)
		var z := _rng.randf_range(-460.0, 460.0)
		var ground := _height_at(x, z)
		var slope := _slope_at(x, z)
		if ground < 17.0 or slope < 0.72 or ground > 56.0:
			continue
		var size := _rng.randf_range(2.0, 8.5)
		ridge_rocks.append(_make_transform(
			Vector3(x, ground + size * 0.22, z),
			_rng.randf_range(0.0, TAU),
			Vector3(size * _rng.randf_range(1.0, 1.8), size * 0.85, size)
		))

	for i in range(900):
		var x := _rng.randf_range(-ISLAND_RX * 0.98, ISLAND_RX * 0.98)
		var z := _rng.randf_range(-ISLAND_RZ * 0.98, ISLAND_RZ * 0.98)
		var ground := _height_at(x, z)
		if ground < 0.8 or ground > 38.0:
			continue
		if _near_river(x, z, 9.0) or _near_lake(x, z, 18.0):
			continue
		var size := _rng.randf_range(0.18, 0.72)
		scree.append(_make_transform(
			Vector3(x, ground + size * 0.28, z),
			_rng.randf_range(0.0, TAU),
			Vector3(size * _rng.randf_range(0.8, 1.8), size * 0.65, size)
		))

	_add_multimesh("JaggedCoastalRockShelves", _rock_mesh, shoreline_rocks, _rock_material)
	_add_multimesh("MountainScreeOutcrops", _rock_mesh, ridge_rocks, _rock_material)
	_add_multimesh("FineScatteredScree", _rock_mesh, scree, _rock_material)



func _create_beach_tide_pools_and_driftwood() -> void:
	var driftwood_mesh := CylinderMesh.new()
	driftwood_mesh.top_radius = 0.22
	driftwood_mesh.bottom_radius = 0.34
	driftwood_mesh.height = 1.0
	driftwood_mesh.radial_segments = 6
	var driftwood_material := _make_bark_material(Color(0.19, 0.145, 0.105))
	var driftwood: Array[Transform3D] = []
	var beach_pebbles: Array[Transform3D] = []
	var foam_stones: Array[Transform3D] = []

	# Beach debris follows the irregular coast instead of forming a perfect ring.
	for i in range(460):
		var angle := _rng.randf_range(0.0, TAU)
		var radial := _rng.randf_range(0.885, 1.005)
		var x := cos(angle) * ISLAND_RX * radial
		var z := sin(angle) * ISLAND_RZ * radial
		var ground := _height_at(x, z)
		if ground < SEA_LEVEL - 0.2 or ground > 2.8:
			continue
		var size := _rng.randf_range(0.12, 0.48)
		beach_pebbles.append(_make_transform(
			Vector3(x, ground + size * 0.35, z),
			_rng.randf_range(0.0, TAU),
			Vector3(size * _rng.randf_range(1.0, 2.2), size * 0.55, size)
		))

	for i in range(58):
		var angle := _rng.randf_range(0.0, TAU)
		var radial := _rng.randf_range(0.87, 0.96)
		var x := cos(angle) * ISLAND_RX * radial
		var z := sin(angle) * ISLAND_RZ * radial
		var ground := _height_at(x, z)
		if ground < SEA_LEVEL + 0.1 or ground > 4.5:
			continue
		var length := _rng.randf_range(3.0, 10.0)
		var rotation := _rng.randf_range(0.0, TAU)
		var log_basis := Basis(Vector3.UP, rotation) * Basis(Vector3.RIGHT, PI * 0.5)
		log_basis = log_basis.scaled(Vector3(0.42, length, 0.42))
		driftwood.append(Transform3D(log_basis, Vector3(x, ground + 0.22, z)))

	for i in range(95):
		var angle := _rng.randf_range(0.0, TAU)
		var radial := _rng.randf_range(0.91, 1.025)
		var x := cos(angle) * ISLAND_RX * radial
		var z := sin(angle) * ISLAND_RZ * radial
		var ground := _height_at(x, z)
		if ground < SEA_LEVEL - 0.5 or ground > 1.2:
			continue
		var size := _rng.randf_range(0.35, 1.25)
		foam_stones.append(_make_transform(
			Vector3(x, ground + size * 0.22, z),
			_rng.randf_range(0.0, TAU),
			Vector3(size * 1.7, size * 0.48, size)
		))

	_add_multimesh("WeatheredBeachPebbles", _rock_mesh, beach_pebbles, _rock_material)
	_add_multimesh("TideLineFoamStones", _rock_mesh, foam_stones, _sand_material)
	_add_multimesh("SaltWornDriftwood", driftwood_mesh, driftwood, driftwood_material)

	# A few shallow pools sit just inland from the surf, using the actual terrain height.
	var pool_material := StandardMaterial3D.new()
	pool_material.albedo_color = Color(0.035, 0.12, 0.13, 0.88)
	pool_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pool_material.roughness = 0.22
	for i in range(8):
		var angle := TAU * float(i) / 8.0 + 0.18
		var radial := 0.89
		var x := cos(angle) * ISLAND_RX * radial
		var z := sin(angle) * ISLAND_RZ * radial
		var ground := _height_at(x, z)
		if ground < 0.0 or ground > 3.2:
			continue
		var pool_mesh := PlaneMesh.new()
		pool_mesh.size = Vector2(_rng.randf_range(5.0, 11.0), _rng.randf_range(3.0, 7.0))
		var pool := MeshInstance3D.new()
		pool.name = "RockPool_%02d" % i
		pool.mesh = pool_mesh
		pool.material_override = pool_material
		pool.position = Vector3(x, ground + 0.08, z)
		pool.rotation_degrees.y = _rng.randf_range(0.0, 180.0)
		pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(pool)



func _create_mountain_streams_and_waterfalls() -> void:
	var water_material := StandardMaterial3D.new()
	water_material.albedo_color = Color(0.055, 0.24, 0.27, 0.82)
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.roughness = 0.2
	water_material.metallic = 0.08
	water_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var foam_material := StandardMaterial3D.new()
	foam_material.albedo_color = Color(0.58, 0.72, 0.68, 0.68)
	foam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foam_material.roughness = 0.3
	foam_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Two narrow tributaries cut through the northern and central highlands.
	var northern_route := PackedVector3Array([
		Vector3(76.0, 0.0, -390.0),
		Vector3(94.0, 0.0, -340.0),
		Vector3(72.0, 0.0, -300.0),
		Vector3(86.0, 0.0, -258.0),
		Vector3(64.0, 0.0, -218.0)
	])
	var western_route := PackedVector3Array([
		Vector3(-258.0, 0.0, -212.0),
		Vector3(-218.0, 0.0, -178.0),
		Vector3(-176.0, 0.0, -142.0),
		Vector3(-132.0, 0.0, -112.0),
		Vector3(-88.0, 0.0, -78.0)
	])
	_create_stream_ribbon("NorthernMountainTributary", northern_route, 2.8, water_material)
	_create_stream_ribbon("WesternRidgeTributary", western_route, 2.1, water_material)

	# Waterfall curtains are placed in narrow rocky cuts. Their vertical sheets
	# are double-sided and use translucent material to remain visible on mobile.
	_create_waterfall_curtain("NorthRidgeWaterfall", Vector3(86.0, 0.0, -258.0), 7.5, 5.0, water_material, foam_material)
	_create_waterfall_curtain("WestRidgeCascade", Vector3(-176.0, 0.0, -142.0), 5.0, 3.8, water_material, foam_material)


func _create_stream_ribbon(stream_name: String, route: PackedVector3Array, width: float, material: Material) -> void:
	if route.size() < 2:
		return
	var vertices: Array[Vector3] = []
	var indices := PackedInt32Array()
	const STEPS_PER_SEGMENT := 18
	for segment in range(route.size() - 1):
		for step in range(STEPS_PER_SEGMENT + 1):
			if segment > 0 and step == 0:
				continue
			var t := float(step) / float(STEPS_PER_SEGMENT)
			var point := route[segment].lerp(route[segment + 1], t)
			var previous := route[max(segment - 1, 0)].lerp(route[segment], max(t - 0.04, 0.0))
			var next := route[min(segment + 2, route.size() - 1)].lerp(route[segment + 1], min(t + 0.04, 1.0))
			var tangent := Vector2(next.x - previous.x, next.z - previous.z).normalized()
			var side := Vector2(-tangent.y, tangent.x) * width * 0.5
			var y := _height_at(point.x, point.z) + 0.24
			vertices.append(Vector3(point.x + side.x, y, point.z + side.y))
			vertices.append(Vector3(point.x - side.x, y, point.z - side.y))
	for i in range((vertices.size() / 2) - 1):
		var a := i * 2
		indices.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in vertices:
		surface.set_color(Color(0.78, 0.9, 0.86))
		surface.add_vertex(vertex)
	for index in indices:
		surface.add_index(index)
	surface.generate_normals()
	var stream := MeshInstance3D.new()
	stream.name = stream_name
	stream.mesh = surface.commit()
	stream.material_override = material
	stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stream)


func _create_waterfall_curtain(fall_name: String, location: Vector3, drop: float, width: float, water_material: Material, foam_material: Material) -> void:
	var x := location.x
	var z := location.z
	var upper_y := _height_at(x, z) + 0.45
	var lower_y := upper_y - drop
	var fall := MeshInstance3D.new()
	fall.name = fall_name
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var left_top := Vector3(x - width * 0.5, upper_y, z)
	var right_top := Vector3(x + width * 0.5, upper_y, z)
	var left_bottom := Vector3(x - width * 0.5, lower_y, z + 0.35)
	var right_bottom := Vector3(x + width * 0.5, lower_y, z + 0.35)
	for vertex in [left_top, left_bottom, right_top, right_top, left_bottom, right_bottom]:
		surface.set_color(Color(0.72, 0.88, 0.84, 0.82))
		surface.add_vertex(vertex)
	surface.generate_normals()
	fall.mesh = surface.commit()
	fall.material_override = water_material
	fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fall)

	var plunge_pool := MeshInstance3D.new()
	plunge_pool.name = fall_name + "PlungePool"
	var pool_mesh := PlaneMesh.new()
	pool_mesh.size = Vector2(width * 2.8, width * 1.9)
	plunge_pool.mesh = pool_mesh
	plunge_pool.material_override = water_material
	plunge_pool.position = Vector3(x, _height_at(x, z + 5.0) + 0.3, z + 5.0)
	plunge_pool.rotation_degrees.y = 12.0
	plunge_pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plunge_pool)

	var spray := MeshInstance3D.new()
	spray.name = fall_name + "Mist"
	var spray_mesh := PlaneMesh.new()
	spray_mesh.size = Vector2(width * 1.7, drop * 0.8)
	spray.mesh = spray_mesh
	spray.material_override = foam_material
	spray.position = Vector3(x, lower_y + drop * 0.35, z + 0.8)
	spray.rotation_degrees.y = 90.0
	spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(spray)



func _create_biome_groundcover() -> void:
	var fern_material := _make_pine_material(Color(0.075, 0.19, 0.095))
	var fern_light_material := _make_pine_material(Color(0.13, 0.25, 0.12))
	var reed_material := StandardMaterial3D.new()
	reed_material.albedo_color = Color(0.28, 0.31, 0.16)
	reed_material.roughness = 1.0
	var dead_reed_material := StandardMaterial3D.new()
	dead_reed_material.albedo_color = Color(0.31, 0.27, 0.17)
	dead_reed_material.roughness = 1.0

	var fern_mesh := CylinderMesh.new()
	fern_mesh.bottom_radius = 0.34
	fern_mesh.top_radius = 0.015
	fern_mesh.height = 1.15
	fern_mesh.radial_segments = 5
	var reed_mesh := CylinderMesh.new()
	reed_mesh.top_radius = 0.035
	reed_mesh.bottom_radius = 0.075
	reed_mesh.height = 1.8
	reed_mesh.radial_segments = 4
	var dead_reed_mesh := CylinderMesh.new()
	dead_reed_mesh.top_radius = 0.025
	dead_reed_mesh.bottom_radius = 0.065
	dead_reed_mesh.height = 1.25
	dead_reed_mesh.radial_segments = 4

	var ferns: Array[Transform3D] = []
	var light_ferns: Array[Transform3D] = []
	var reeds: Array[Transform3D] = []
	var dead_reeds: Array[Transform3D] = []
	var attempts := 0
	while ferns.size() + light_ferns.size() < 1150 and attempts < 9500:
		attempts += 1
		var x := _rng.randf_range(-ISLAND_RX * 0.94, ISLAND_RX * 0.94)
		var z := _rng.randf_range(-ISLAND_RZ * 0.94, ISLAND_RZ * 0.94)
		var ground := _height_at(x, z)
		if ground < 1.0 or ground > 24.0 or _slope_at(x, z) > 1.35:
			continue
		if _near_river(x, z, 20.0) or _near_lake(x, z, 38.0):
			continue
		if _in_clearing(x, z):
			continue
		var size := _rng.randf_range(0.65, 1.45)
		var transform := _make_transform(Vector3(x, ground + 0.52 * size, z), _rng.randf_range(0.0, TAU), Vector3(size, size, size))
		if _rng.randf() < 0.72:
			ferns.append(transform)
		else:
			light_ferns.append(transform)

	# Dense wetland reeds frame the swamp pools and low river banks.
	for i in range(620):
		var x := 420.0 + _rng.randf_range(-104.0, 104.0)
		var z := 310.0 + _rng.randf_range(-88.0, 88.0)
		var ground := _height_at(x, z)
		if ground < 0.0 or ground > 8.0:
			continue
		var height_scale := _rng.randf_range(0.65, 1.55)
		var rotation := _rng.randf_range(0.0, TAU)
		var base := Vector3(x, ground + 0.78 * height_scale, z)
		reeds.append(_make_transform(base, rotation, Vector3.ONE * height_scale))
		if _rng.randf() < 0.3:
			dead_reeds.append(_make_transform(base + Vector3(0.2, -0.18, 0.1), rotation + 0.7, Vector3.ONE * height_scale * 0.8))

	_add_multimesh("ForestFernGroundcover", fern_mesh, ferns, fern_material)
	_add_multimesh("SunlitFernGroundcover", fern_mesh, light_ferns, fern_light_material)
	_add_multimesh("SwampReedBeds", reed_mesh, reeds, reed_material)
	_add_multimesh("DrySwampReeds", dead_reed_mesh, dead_reeds, dead_reed_material)



func _create_ravine_boulder_fields() -> void:
	var boulders: Array[Transform3D] = []
	var exposed_roots: Array[Transform3D] = []
	var root_mesh := CylinderMesh.new()
	root_mesh.top_radius = 0.11
	root_mesh.bottom_radius = 0.2
	root_mesh.height = 1.0
	root_mesh.radial_segments = 5
	var root_material := _make_bark_material(Color(0.16, 0.12, 0.085))

	for i in range(420):
		var z := _rng.randf_range(-270.0, 185.0)
		var center_x := -82.0 + sin(z * 0.0085) * 52.0
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var x := center_x + side * _rng.randf_range(14.0, 58.0)
		var ground := _height_at(x, z)
		if ground < 2.0 or ground > 42.0:
			continue
		var size := _rng.randf_range(0.8, 4.8)
		boulders.append(_make_transform(
			Vector3(x, ground + size * 0.26, z),
			_rng.randf_range(0.0, TAU),
			Vector3(size * _rng.randf_range(1.0, 1.7), size * 0.78, size)
		))

	for i in range(105):
		var z := _rng.randf_range(-255.0, 150.0)
		var center_x := -82.0 + sin(z * 0.0085) * 52.0
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var x := center_x + side * _rng.randf_range(28.0, 72.0)
		var ground := _height_at(x, z)
		if ground < 3.0 or ground > 30.0:
			continue
		var length := _rng.randf_range(2.5, 7.0)
		var angle := _rng.randf_range(0.0, TAU)
		var root_basis := Basis(Vector3.UP, angle) * Basis(Vector3.RIGHT, PI * 0.5)
		root_basis = root_basis.scaled(Vector3(0.2, length, 0.2))
		exposed_roots.append(Transform3D(root_basis, Vector3(x, ground + 0.2, z)))

	_add_multimesh("RavineBoulderFields", _rock_mesh, boulders, _rock_material)
	_add_multimesh("ExposedRavineRoots", root_mesh, exposed_roots, root_material)



func _create_natural_rock_arches() -> void:
	var arch_stones: Array[Transform3D] = []
	var standing_stones: Array[Transform3D] = []
	var arch_centers: Array[Vector2] = [
		Vector2(-292.0, -250.0),
		Vector2(278.0, 126.0)
	]
	for center in arch_centers:
		var ground := _height_at(center.x, center.y)
		var span := _rng.randf_range(13.0, 17.0)
		var height := _rng.randf_range(12.0, 16.0)
		var stone_count := 13
		for i in range(stone_count):
			var angle := PI * float(i) / float(stone_count - 1)
			var x: float = center.x + cos(angle) * span
			var y: float = ground + 1.0 + sin(angle) * height
			var z: float = center.y + sin(angle) * 2.4
			var size := _rng.randf_range(2.4, 4.8)
			var scale := Vector3(size * 0.72, size * 1.25, size * 0.8)
			arch_stones.append(_make_transform(
				Vector3(x, y, z),
				_rng.randf_range(-0.22, 0.22),
				scale
			))
		for side in [-1.0, 1.0]:
			var pillar_x: float = center.x + side * span
			var pillar_ground := _height_at(pillar_x, center.y)
			var pillar_size := _rng.randf_range(3.0, 5.0)
			standing_stones.append(_make_transform(
				Vector3(pillar_x, pillar_ground + pillar_size * 1.15, center.y + _rng.randf_range(-2.0, 2.0)),
				_rng.randf_range(-0.18, 0.18),
				Vector3(pillar_size * 0.8, pillar_size * 2.4, pillar_size * 0.72)
			))

	_add_multimesh("NaturalStoneArchRings", _rock_mesh, arch_stones, _rock_material)
	_add_multimesh("WeatheredStandingStones", _rock_mesh, standing_stones, _rock_material)



func _create_highland_meadow_details() -> void:
	var flower_mesh := SphereMesh.new()
	flower_mesh.radius = 0.16
	flower_mesh.height = 0.22
	flower_mesh.radial_segments = 6
	flower_mesh.rings = 4
	var flower_white := StandardMaterial3D.new()
	flower_white.albedo_color = Color(0.78, 0.76, 0.58)
	flower_white.roughness = 0.9
	var flower_purple := StandardMaterial3D.new()
	flower_purple.albedo_color = Color(0.42, 0.31, 0.48)
	flower_purple.roughness = 0.9
	var meadow_grass := StandardMaterial3D.new()
	meadow_grass.albedo_color = Color(0.28, 0.32, 0.17)
	meadow_grass.roughness = 1.0
	var grass_mesh := CylinderMesh.new()
	grass_mesh.top_radius = 0.012
	grass_mesh.bottom_radius = 0.09
	grass_mesh.height = 0.54
	grass_mesh.radial_segments = 4

	var white_flowers: Array[Transform3D] = []
	var purple_flowers: Array[Transform3D] = []
	var grass_tufts: Array[Transform3D] = []
	var attempts := 0
	while white_flowers.size() + purple_flowers.size() < 420 and attempts < 6800:
		attempts += 1
		var x := _rng.randf_range(-500.0, 500.0)
		var z := _rng.randf_range(-430.0, 430.0)
		var ground := _height_at(x, z)
		if ground < 17.0 or ground > 49.0 or _slope_at(x, z) > 1.15:
			continue
		if _near_river(x, z, 13.0) or _near_lake(x, z, 28.0) or _in_clearing(x, z):
			continue
		var size := _rng.randf_range(0.65, 1.25)
		var transform := _make_transform(Vector3(x, ground + 0.22 * size, z), _rng.randf_range(0.0, TAU), Vector3.ONE * size)
		if _rng.randf() < 0.55:
			white_flowers.append(transform)
		else:
			purple_flowers.append(transform)
		if _rng.randf() < 0.48:
			grass_tufts.append(_make_transform(Vector3(x + 0.3, ground + 0.24, z - 0.2), _rng.randf_range(0.0, TAU), Vector3.ONE * _rng.randf_range(0.7, 1.3)))

	_add_multimesh("HighlandWhiteWildflowers", flower_mesh, white_flowers, flower_white)
	_add_multimesh("HighlandPurpleWildflowers", flower_mesh, purple_flowers, flower_purple)
	_add_multimesh("AlpineMeadowGrassTufts", grass_mesh, grass_tufts, meadow_grass)



func _create_stream_bank_gravel() -> void:
	var gravel: Array[Transform3D] = []
	var routes: Array[PackedVector3Array] = [
		PackedVector3Array([
			Vector3(76.0, 0.0, -390.0),
			Vector3(94.0, 0.0, -340.0),
			Vector3(72.0, 0.0, -300.0),
			Vector3(86.0, 0.0, -258.0),
			Vector3(64.0, 0.0, -218.0)
		]),
		PackedVector3Array([
			Vector3(-258.0, 0.0, -212.0),
			Vector3(-218.0, 0.0, -178.0),
			Vector3(-176.0, 0.0, -142.0),
			Vector3(-132.0, 0.0, -112.0),
			Vector3(-88.0, 0.0, -78.0)
		])
	]
	for route in routes:
		for segment in range(route.size() - 1):
			var start: Vector3 = route[segment]
			var finish: Vector3 = route[segment + 1]
			var direction := Vector2(finish.x - start.x, finish.z - start.z).normalized()
			var side := Vector2(-direction.y, direction.x)
			for step in range(32):
				var t := (float(step) + _rng.randf()) / 32.0
				var center: Vector3 = start.lerp(finish, t)
				for bank_side in [-1.0, 1.0]:
					var offset: float = _rng.randf_range(2.0, 6.5) * bank_side
					var x: float = center.x + side.x * offset
					var z: float = center.z + side.y * offset
					var ground := _height_at(x, z)
					if ground < 1.0 or ground > 54.0:
						continue
					var size := _rng.randf_range(0.12, 0.52)
					gravel.append(_make_transform(
						Vector3(x, ground + size * 0.3, z),
						_rng.randf_range(0.0, TAU),
						Vector3(size * _rng.randf_range(1.0, 2.0), size * 0.6, size)
					))

	_add_multimesh("MountainStreamBankGravel", _rock_mesh, gravel, _rock_material)



func _create_cliff_outcrops() -> void:
	var cliff_faces: Array[Transform3D] = []
	var talus: Array[Transform3D] = []
	var attempts := 0
	while cliff_faces.size() < 360 and attempts < 7200:
		attempts += 1
		var x := _rng.randf_range(-ISLAND_RX * 0.91, ISLAND_RX * 0.91)
		var z := _rng.randf_range(-ISLAND_RZ * 0.91, ISLAND_RZ * 0.91)
		var ground := _height_at(x, z)
		var slope := _slope_at(x, z)
		if ground < 9.0 or ground > 58.0 or slope < 1.25:
			continue
		if _near_river(x, z, 9.0) or _near_lake(x, z, 20.0) or _in_clearing(x, z):
			continue
		var size := _rng.randf_range(2.2, 7.8)
		var dx := _height_at(x + 3.0, z) - _height_at(x - 3.0, z)
		var dz := _height_at(x, z + 3.0) - _height_at(x, z - 3.0)
		var face_angle := atan2(dz, dx) + PI * 0.5
		cliff_faces.append(_make_transform(
			Vector3(x, ground + size * 0.42, z),
			face_angle,
			Vector3(size * _rng.randf_range(1.0, 2.2), size * _rng.randf_range(0.8, 1.5), size * 0.62)
		))
		if _rng.randf() < 0.7:
			for j in range(_rng.randi_range(1, 3)):
				var offset_x := _rng.randf_range(-size * 1.6, size * 1.6)
				var offset_z := _rng.randf_range(-size * 1.6, size * 1.6)
				var debris_size := _rng.randf_range(0.5, 1.8)
				talus.append(_make_transform(
					Vector3(x + offset_x, _height_at(x + offset_x, z + offset_z) + debris_size * 0.28, z + offset_z),
					_rng.randf_range(0.0, TAU),
					Vector3(debris_size * 1.6, debris_size * 0.8, debris_size)
				))

	_add_multimesh("JaggedMountainCliffFaces", _rock_mesh, cliff_faces, _rock_material)
	_add_multimesh("CliffBaseTalus", _rock_mesh, talus, _rock_material)




func _create_northern_ridge_spires() -> void:
	var spire_mesh := CylinderMesh.new()
	spire_mesh.top_radius = 0.035
	spire_mesh.bottom_radius = 1.0
	spire_mesh.height = 1.0
	spire_mesh.radial_segments = 6
	var spires: Array[Transform3D] = []
	var cairn_stones: Array[Transform3D] = []
	var talus: Array[Transform3D] = []
	var summit_centers: Array[Vector2] = [
		Vector2(270.0, -330.0),
		Vector2(205.0, -370.0),
		Vector2(326.0, -285.0)
	]

	for center: Vector2 in summit_centers:
		var summit_ground: float = _height_at(center.x, center.y)
		for i in range(6):
			var angle: float = TAU * float(i) / 6.0 + _rng.randf_range(-0.22, 0.22)
			var radial: float = _rng.randf_range(5.0, 19.0)
			var x: float = center.x + cos(angle) * radial
			var z: float = center.y + sin(angle) * radial
			var ground: float = _height_at(x, z)
			if ground < 22.0 or ground > 58.0:
				continue
			var spire_height: float = _rng.randf_range(8.0, 16.5)
			var spire_width: float = _rng.randf_range(1.15, 2.25)
			var yaw: float = _rng.randf_range(0.0, TAU)
			var lean: float = _rng.randf_range(-0.16, 0.16)
			var spire_basis: Basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, lean)
			spire_basis = spire_basis.scaled(Vector3(spire_width, spire_height, spire_width))
			spires.append(Transform3D(
				spire_basis,
				Vector3(x, ground + spire_height * 0.5, z)
			))

		# A low cairn marks each high point without introducing a game objective.
		for layer in range(4):
			var stone_size: float = 1.15 - float(layer) * 0.19
			var stone_y: float = summit_ground + 0.45 + float(layer) * 0.68
			cairn_stones.append(_make_transform(
				Vector3(center.x, stone_y, center.y),
				_rng.randf_range(0.0, TAU),
				Vector3(stone_size * 1.25, stone_size * 0.55, stone_size)
			))

	for i in range(320):
		var x: float = 270.0 + _rng.randf_range(-92.0, 92.0)
		var z: float = -330.0 + _rng.randf_range(-82.0, 82.0)
		var ground: float = _height_at(x, z)
		if ground < 16.0 or ground > 55.0 or _slope_at(x, z) > 1.8:
			continue
		var size: float = _rng.randf_range(0.45, 2.3)
		talus.append(_make_transform(
			Vector3(x, ground + size * 0.26, z),
			_rng.randf_range(0.0, TAU),
			Vector3(size * _rng.randf_range(1.0, 1.8), size * 0.72, size)
		))

	_add_multimesh("NorthernGraniteRidgePinnacles", spire_mesh, spires, _rock_material)
	_add_multimesh("NorthernSummitTrailCairns", _rock_mesh, cairn_stones, _rock_material)
	_add_multimesh("NorthernSummitScree", _rock_mesh, talus, _rock_material)


func _create_highland_deadwood() -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.12
	trunk_mesh.bottom_radius = 0.32
	trunk_mesh.height = 1.0
	trunk_mesh.radial_segments = 6
	var snag_material := _make_bark_material(Color(0.25, 0.22, 0.17))
	var branch_mesh := CylinderMesh.new()
	branch_mesh.top_radius = 0.035
	branch_mesh.bottom_radius = 0.12
	branch_mesh.height = 1.0
	branch_mesh.radial_segments = 5
	var trunks: Array[Transform3D] = []
	var branches: Array[Transform3D] = []
	var attempts := 0
	while trunks.size() < 42 and attempts < 2600:
		attempts += 1
		var x := _rng.randf_range(-470.0, 470.0)
		var z := _rng.randf_range(-410.0, 410.0)
		var ground := _height_at(x, z)
		if ground < 30.0 or ground > 58.0 or _slope_at(x, z) > 1.2:
			continue
		if _near_river(x, z, 24.0) or _near_lake(x, z, 42.0) or _in_clearing(x, z):
			continue
		var height := _rng.randf_range(5.0, 9.0)
		var radius := _rng.randf_range(0.55, 0.95)
		var lean := _rng.randf_range(-0.18, 0.18)
		var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)) * Basis(Vector3.RIGHT, lean)
		basis = basis.scaled(Vector3(radius, height, radius))
		trunks.append(Transform3D(basis, Vector3(x, ground + height * 0.42, z)))
		for j in range(3):
			var branch_height := ground + height * _rng.randf_range(0.58, 0.9)
			var branch_angle := _rng.randf_range(0.0, TAU)
			var branch_length := _rng.randf_range(1.1, 2.2)
			var branch_basis := Basis(Vector3.UP, branch_angle) * Basis(Vector3.RIGHT, _rng.randf_range(0.75, 1.25))
			branch_basis = branch_basis.scaled(Vector3(0.11, branch_length, 0.11))
			branches.append(Transform3D(branch_basis, Vector3(x, branch_height, z)))

	_add_multimesh("HighlandWeatheredSnags", trunk_mesh, trunks, snag_material)
	_add_multimesh("BrokenSnagBranches", branch_mesh, branches, snag_material)



func _create_swamp_water_channels() -> void:
	var channel_material := StandardMaterial3D.new()
	channel_material.albedo_color = Color(0.035, 0.105, 0.085, 0.86)
	channel_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	channel_material.roughness = 0.18
	channel_material.metallic = 0.04
	channel_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var western_channel := PackedVector3Array([
		Vector3(334.0, 0.0, 264.0),
		Vector3(362.0, 0.0, 282.0),
		Vector3(391.0, 0.0, 300.0),
		Vector3(420.0, 0.0, 310.0)
	])
	var eastern_channel := PackedVector3Array([
		Vector3(420.0, 0.0, 310.0),
		Vector3(448.0, 0.0, 325.0),
		Vector3(478.0, 0.0, 347.0),
		Vector3(505.0, 0.0, 369.0)
	])
	var southern_channel := PackedVector3Array([
		Vector3(388.0, 0.0, 365.0),
		Vector3(402.0, 0.0, 340.0),
		Vector3(420.0, 0.0, 310.0),
		Vector3(434.0, 0.0, 284.0)
	])
	_create_stream_ribbon("SwampWesternWaterChannel", western_channel, 3.8, channel_material)
	_create_stream_ribbon("SwampEasternWaterChannel", eastern_channel, 2.7, channel_material)
	_create_stream_ribbon("SwampSouthernWaterChannel", southern_channel, 2.3, channel_material)

	var bank_stones: Array[Transform3D] = []
	for i in range(260):
		var x := 420.0 + _rng.randf_range(-112.0, 112.0)
		var z := 310.0 + _rng.randf_range(-88.0, 88.0)
		if _height_at(x, z) < 0.0 or _height_at(x, z) > 9.0:
			continue
		if _near_river(x, z, 12.0):
			continue
		var size := _rng.randf_range(0.18, 0.62)
		bank_stones.append(_make_transform(
			Vector3(x, _height_at(x, z) + size * 0.3, z),
			_rng.randf_range(0.0, TAU),
			Vector3(size * 1.8, size * 0.6, size)
		))
	_add_multimesh("SwampWaterlineStones", _rock_mesh, bank_stones, _rock_material)



func _create_swamp_surface_details() -> void:
	var lily_mesh := SphereMesh.new()
	lily_mesh.radius = 0.72
	lily_mesh.height = 0.12
	lily_mesh.radial_segments = 7
	lily_mesh.rings = 3
	var lily_material := StandardMaterial3D.new()
	lily_material.albedo_color = Color(0.13, 0.22, 0.105)
	lily_material.roughness = 0.82
	var root_mesh := CylinderMesh.new()
	root_mesh.top_radius = 0.035
	root_mesh.bottom_radius = 0.19
	root_mesh.height = 1.0
	root_mesh.radial_segments = 5
	var root_material := _make_bark_material(Color(0.14, 0.12, 0.085))

	var lily_pads: Array[Transform3D] = []
	var cypress_knees: Array[Transform3D] = []
	var attempts := 0
	while lily_pads.size() < 110 and attempts < 1800:
		attempts += 1
		var x := 420.0 + _rng.randf_range(-104.0, 104.0)
		var z := 310.0 + _rng.randf_range(-82.0, 82.0)
		var ground := _height_at(x, z)
		if ground < 0.0 or ground > 3.6 or _near_river(x, z, 10.0):
			continue
		var size := _rng.randf_range(0.65, 1.25)
		lily_pads.append(_make_transform(
			Vector3(x, ground + 0.2, z),
			_rng.randf_range(0.0, TAU),
			Vector3(size, 0.16, size * _rng.randf_range(0.75, 1.25))
		))

	for i in range(125):
		var x := 420.0 + _rng.randf_range(-112.0, 112.0)
		var z := 310.0 + _rng.randf_range(-92.0, 92.0)
		var ground := _height_at(x, z)
		if ground < 0.5 or ground > 6.0:
			continue
		var height := _rng.randf_range(0.55, 1.5)
		var size := _rng.randf_range(0.7, 1.25)
		cypress_knees.append(_make_transform(
			Vector3(x, ground + height * 0.5, z),
			_rng.randf_range(0.0, TAU),
			Vector3(size, height, size)
		))

	_add_multimesh("SwampFloatingLilyPads", lily_mesh, lily_pads, lily_material)
	_add_multimesh("SwampCypressRootKnees", root_mesh, cypress_knees, root_material)



func _western_tarn_basin_at(x: float, z: float) -> float:
	return 12.0 * exp(-pow((x + 300.0) / 68.0, 2.0) - pow((z - 180.0) / 52.0, 2.0))


func _western_tarn_water_level() -> float:
	return _height_at(-300.0, 180.0) + 4.0


func _create_western_tarn() -> void:
	var tarn_mesh := PlaneMesh.new()
	tarn_mesh.size = Vector2(112.0, 88.0)
	tarn_mesh.subdivide_width = 28
	tarn_mesh.subdivide_depth = 22
	var tarn := MeshInstance3D.new()
	tarn.name = "WesternHighlandTarn"
	tarn.mesh = tarn_mesh
	tarn.material_override = _water_material
	tarn.position = Vector3(-300.0, _western_tarn_water_level(), 180.0)
	tarn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tarn)


func _create_western_tarn_shoreline() -> void:
	var shore_pebbles: Array[Transform3D] = []
	var fallen_logs: Array[Transform3D] = []
	var log_mesh := CylinderMesh.new()
	log_mesh.top_radius = 0.13
	log_mesh.bottom_radius = 0.22
	log_mesh.height = 1.0
	log_mesh.radial_segments = 6
	var log_material := _make_bark_material(Color(0.19, 0.15, 0.105))
	var water_level := _western_tarn_water_level()

	for i in range(190):
		var angle := TAU * float(i) / 190.0 + _rng.randf_range(-0.025, 0.025)
		var radial := _rng.randf_range(0.96, 1.22)
		var x := -300.0 + cos(angle) * 54.0 * radial
		var z := 180.0 + sin(angle) * 42.0 * radial
		var ground := _height_at(x, z)
		if ground <= water_level + 0.35 or ground > 19.0:
			continue
		var size := _rng.randf_range(0.35, 1.35)
		shore_pebbles.append(_make_transform(
			Vector3(x, ground + size * 0.28, z),
			_rng.randf_range(0.0, TAU),
			Vector3(size * _rng.randf_range(1.0, 1.8), size * 0.62, size)
		))

	for i in range(18):
		var angle := _rng.randf_range(0.0, TAU)
		var radial := _rng.randf_range(0.88, 1.14)
		var x := -300.0 + cos(angle) * 52.0 * radial
		var z := 180.0 + sin(angle) * 40.0 * radial
		var ground := _height_at(x, z)
		if ground <= water_level + 0.45 or ground > 20.0:
			continue
		var length := _rng.randf_range(2.5, 6.5)
		var log_basis := Basis(Vector3.UP, angle) * Basis(Vector3.RIGHT, PI * 0.5)
		log_basis = log_basis.scaled(Vector3(0.22, length, 0.22))
		fallen_logs.append(Transform3D(log_basis, Vector3(x, ground + 0.2, z)))

	_add_multimesh("WesternTarnShorePebbles", _rock_mesh, shore_pebbles, _rock_material)
	_add_multimesh("WesternTarnFallenDriftwood", log_mesh, fallen_logs, log_material)



func _create_western_tarn_grove() -> void:
	var birch_trunk_mesh := CylinderMesh.new()
	birch_trunk_mesh.top_radius = 0.18
	birch_trunk_mesh.bottom_radius = 0.34
	birch_trunk_mesh.height = 9.0
	birch_trunk_mesh.radial_segments = 7
	var birch_bark := StandardMaterial3D.new()
	birch_bark.albedo_color = Color(0.56, 0.54, 0.45)
	birch_bark.roughness = 0.96

	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.0
	crown_mesh.height = 2.0
	crown_mesh.radial_segments = 8
	crown_mesh.rings = 5
	var crown_material := _make_pine_material(Color(0.105, 0.19, 0.095))
	var understory_mesh := CylinderMesh.new()
	understory_mesh.top_radius = 0.012
	understory_mesh.bottom_radius = 0.11
	understory_mesh.height = 0.8
	understory_mesh.radial_segments = 4
	var understory_material := _make_pine_material(Color(0.23, 0.29, 0.14))

	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var secondary_crowns: Array[Transform3D] = []
	var sedges: Array[Transform3D] = []
	var attempts := 0
	while trunks.size() < 34 and attempts < 2600:
		attempts += 1
		var angle := _rng.randf_range(0.0, TAU)
		var radial := _rng.randf_range(1.22, 1.72)
		var x := -300.0 + cos(angle) * 64.0 * radial
		var z := 180.0 + sin(angle) * 50.0 * radial
		var ground := _height_at(x, z)
		if ground < 3.0 or ground > 27.0 or _slope_at(x, z) > 1.15:
			continue
		if _near_river(x, z, 24.0) or _in_clearing(x, z):
			continue
		var scale := _rng.randf_range(0.82, 1.24)
		trunks.append(_make_transform(
			Vector3(x, ground + 4.5 * scale, z),
			_rng.randf_range(-0.08, 0.08),
			Vector3.ONE * scale
		))
		crowns.append(_make_transform(
			Vector3(x, ground + 9.1 * scale, z),
			_rng.randf_range(0.0, TAU),
			Vector3(3.5, 3.0, 3.3) * scale
		))
		secondary_crowns.append(_make_transform(
			Vector3(x + _rng.randf_range(-1.4, 1.4), ground + 10.0 * scale, z + _rng.randf_range(-1.2, 1.2)),
			_rng.randf_range(0.0, TAU),
			Vector3(2.2, 2.0, 2.3) * scale
		))

	for i in range(520):
		var angle := _rng.randf_range(0.0, TAU)
		var radial := _rng.randf_range(0.94, 1.3)
		var x := -300.0 + cos(angle) * 64.0 * radial
		var z := 180.0 + sin(angle) * 50.0 * radial
		var ground := _height_at(x, z)
		if ground <= _western_tarn_water_level() + 0.2 or ground > 20.0:
			continue
		if _slope_at(x, z) > 1.5:
			continue
		var size := _rng.randf_range(0.65, 1.3)
		sedges.append(_make_transform(
			Vector3(x, ground + 0.38 * size, z),
			_rng.randf_range(0.0, TAU),
			Vector3.ONE * size
		))

	_add_multimesh("WesternTarnBirchTrunks", birch_trunk_mesh, trunks, birch_bark)
	_add_multimesh("WesternTarnBirchCanopies", crown_mesh, crowns, crown_material)
	_add_multimesh("WesternTarnBirchUpperCanopies", crown_mesh, secondary_crowns, crown_material)
	_add_multimesh("WesternTarnShoreSedges", understory_mesh, sedges, understory_material)



func _create_riverbank_woodland() -> void:
	var alder_trunk_mesh := CylinderMesh.new()
	alder_trunk_mesh.top_radius = 0.17
	alder_trunk_mesh.bottom_radius = 0.31
	alder_trunk_mesh.height = 9.5
	alder_trunk_mesh.radial_segments = 7
	var alder_bark := _make_bark_material(Color(0.22, 0.16, 0.115))

	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radius = 1.0
	canopy_mesh.height = 2.0
	canopy_mesh.radial_segments = 8
	canopy_mesh.rings = 5
	var canopy_material := _make_pine_material(Color(0.12, 0.205, 0.12))
	var sedge_mesh := CylinderMesh.new()
	sedge_mesh.top_radius = 0.018
	sedge_mesh.bottom_radius = 0.09
	sedge_mesh.height = 0.95
	sedge_mesh.radial_segments = 4
	var sedge_material := _make_pine_material(Color(0.22, 0.285, 0.15))

	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var side_crowns: Array[Transform3D] = []
	var sedges: Array[Transform3D] = []
	var attempts := 0
	while trunks.size() < 48 and attempts < 5200:
		attempts += 1
		var t := _rng.randf_range(0.035, 0.965)
		var z: float = lerpf(-356.0, 410.0, t) + _rng.randf_range(-9.0, 9.0)
		var river_x: float = lerpf(110.0, -330.0, t) + sin(t * PI * 3.0) * 48.0
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var x := river_x + side * _rng.randf_range(34.0, 54.0)
		var ground := _height_at(x, z)
		if ground < 1.5 or ground > 29.0 or _slope_at(x, z) > 1.2:
			continue
		if _near_lake(x, z, 46.0) or _in_clearing(x, z):
			continue
		var scale := _rng.randf_range(0.82, 1.24)
		trunks.append(_make_transform(
			Vector3(x, ground + 4.75 * scale, z),
			_rng.randf_range(0.0, TAU),
			Vector3.ONE * scale
		))
		crowns.append(_make_transform(
			Vector3(x, ground + 9.3 * scale, z),
			_rng.randf_range(0.0, TAU),
			Vector3(3.2, 2.7, 3.0) * scale
		))
		side_crowns.append(_make_transform(
			Vector3(x + _rng.randf_range(-1.25, 1.25), ground + 10.0 * scale, z + _rng.randf_range(-1.2, 1.2)),
			_rng.randf_range(0.0, TAU),
			Vector3(2.2, 1.9, 2.3) * scale
		))

	for i in range(1800):
		var t := _rng.randf_range(0.025, 0.975)
		var z: float = lerpf(-356.0, 410.0, t) + _rng.randf_range(-7.0, 7.0)
		var river_x: float = lerpf(110.0, -330.0, t) + sin(t * PI * 3.0) * 48.0
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var x := river_x + side * _rng.randf_range(10.0, 27.0)
		var ground := _height_at(x, z)
		if ground < 0.2 or ground > 20.0 or _slope_at(x, z) > 1.45:
			continue
		if _in_clearing(x, z) or _near_lake(x, z, 24.0):
			continue
		var size := _rng.randf_range(0.7, 1.45)
		sedges.append(_make_transform(
			Vector3(x, ground + 0.46 * size, z),
			_rng.randf_range(0.0, TAU),
			Vector3.ONE * size
		))

	_add_multimesh("RiverbankAlderTrunks", alder_trunk_mesh, trunks, alder_bark)
	_add_multimesh("RiverbankAlderCanopies", canopy_mesh, crowns, canopy_material)
	_add_multimesh("RiverbankAlderSideCanopies", canopy_mesh, side_crowns, canopy_material)
	_add_multimesh("RiverbankSedgeGrass", sedge_mesh, sedges, sedge_material)



func _create_coastal_sea_stacks() -> void:
	var stack_cores: Array[Transform3D] = []
	var stack_caps: Array[Transform3D] = []
	var submerged_rocks: Array[Transform3D] = []
	for i in range(9):
		var angle := TAU * float(i) / 9.0 + 0.16
		var radial := _rng.randf_range(1.105, 1.14)
		var x := cos(angle) * ISLAND_RX * radial
		var z := sin(angle) * ISLAND_RZ * radial
		var base_size := _rng.randf_range(5.5, 8.5)
		var base_height := _rng.randf_range(5.0, 7.5)
		stack_cores.append(_make_transform(
			Vector3(x, SEA_LEVEL - 0.9, z),
			angle,
			Vector3(base_size, base_height, base_size * _rng.randf_range(0.78, 1.12))
		))
		var cap_size := base_size * _rng.randf_range(0.48, 0.72)
		stack_caps.append(_make_transform(
			Vector3(x + _rng.randf_range(-1.2, 1.2), SEA_LEVEL + base_height * 0.72, z + _rng.randf_range(-1.0, 1.0)),
			angle + _rng.randf_range(-0.2, 0.2),
			Vector3(cap_size, base_height * 0.62, cap_size * 0.82)
		))
		for j in range(3):
			var offset_angle := angle + _rng.randf_range(-0.8, 0.8)
			var offset_distance := base_size * _rng.randf_range(0.65, 1.25)
			var small_size := _rng.randf_range(1.8, 3.8)
			var rock_x := x + cos(offset_angle) * offset_distance
			var rock_z := z + sin(offset_angle) * offset_distance
			submerged_rocks.append(_make_transform(
				Vector3(rock_x, SEA_LEVEL - 1.1, rock_z),
				_rng.randf_range(0.0, TAU),
				Vector3(small_size, small_size * _rng.randf_range(0.8, 1.5), small_size * 0.85)
			))

	_add_multimesh("OffshoreSeaStackCores", _rock_mesh, stack_cores, _rock_material)
	_add_multimesh("OffshoreSeaStackCaps", _rock_mesh, stack_caps, _rock_material)
	_add_multimesh("SubmergedCoastalReefRocks", _rock_mesh, submerged_rocks, _rock_material)



func _create_coastal_dune_grass() -> void:
	var dune_grass_mesh := CylinderMesh.new()
	dune_grass_mesh.top_radius = 0.012
	dune_grass_mesh.bottom_radius = 0.095
	dune_grass_mesh.height = 0.82
	dune_grass_mesh.radial_segments = 4
	var dune_grass_material := _make_pine_material(Color(0.255, 0.285, 0.16))
	var salt_shrub_material := StandardMaterial3D.new()
	salt_shrub_material.albedo_color = Color(0.22, 0.255, 0.15)
	salt_shrub_material.roughness = 1.0

	var dune_tufts: Array[Transform3D] = []
	var salt_shrubs: Array[Transform3D] = []
	var attempts := 0
	while dune_tufts.size() < 920 and attempts < 10500:
		attempts += 1
		var angle := _rng.randf_range(0.0, TAU)
		var radial := _rng.randf_range(0.84, 0.995)
		var x := cos(angle) * ISLAND_RX * radial
		var z := sin(angle) * ISLAND_RZ * radial
		var ground := _height_at(x, z)
		if ground < 0.35 or ground > 5.8 or _slope_at(x, z) > 0.95:
			continue
		if _near_river(x, z, 14.0) or _near_lake(x, z, 32.0) or _in_clearing(x, z):
			continue
		var size := _rng.randf_range(0.65, 1.5)
		dune_tufts.append(_make_transform(
			Vector3(x, ground + 0.38 * size, z),
			_rng.randf_range(0.0, TAU),
			Vector3(size, size, size)
		))
		if _rng.randf() < 0.16:
			var shrub_size := _rng.randf_range(0.65, 1.2)
			salt_shrubs.append(_make_transform(
				Vector3(x + _rng.randf_range(-1.0, 1.0), ground + 0.42 * shrub_size, z + _rng.randf_range(-1.0, 1.0)),
				_rng.randf_range(0.0, TAU),
				Vector3(1.25, 0.75, 1.1) * shrub_size
			))

	_add_multimesh("CoastalDuneGrassTufts", dune_grass_mesh, dune_tufts, dune_grass_material)
	_add_multimesh("SaltSprayCoastalShrubs", _bush_mesh, salt_shrubs, salt_shrub_material)



func _create_waterfall_basin_details() -> void:
	var basin_center := Vector2(86.0, -253.0)
	var water_level: float = _height_at(basin_center.x, basin_center.y) + 0.38
	var basin_rocks: Array[Transform3D] = []
	var spray_foam: Array[Transform3D] = []
	var downstream_pebbles: Array[Transform3D] = []

	# A broken granite rim frames the northern waterfall's plunge pool.
	for i in range(42):
		var angle: float = TAU * float(i) / 42.0 + _rng.randf_range(-0.035, 0.035)
		var radius_x: float = _rng.randf_range(10.0, 18.0)
		var radius_z: float = _rng.randf_range(7.0, 14.0)
		var x: float = basin_center.x + cos(angle) * radius_x
		var z: float = basin_center.y + sin(angle) * radius_z
		var ground: float = _height_at(x, z)
		if ground < water_level + 0.45 or ground > 54.0:
			continue
		var size: float = _rng.randf_range(1.3, 4.2)
		basin_rocks.append(_make_transform(
			Vector3(x, ground + size * 0.28, z),
			_rng.randf_range(0.0, TAU),
			Vector3(size * _rng.randf_range(1.0, 1.7), size * 0.82, size)
		))

	# Bright, flattened foam islands sit just above the moving pool surface.
	for i in range(18):
		var angle: float = _rng.randf_range(0.0, TAU)
		var radius: float = _rng.randf_range(1.4, 8.5)
		var x: float = basin_center.x + cos(angle) * radius
		var z: float = basin_center.y + sin(angle) * radius * 0.72
		var size: float = _rng.randf_range(0.45, 1.35)
		spray_foam.append(_make_transform(
			Vector3(x, water_level + 0.12, z),
			_rng.randf_range(0.0, TAU),
			Vector3(size * 1.8, 0.055, size * 0.75)
		))

	# Small rounded stones follow the first few metres of the outgoing stream.
	for i in range(110):
		var t: float = _rng.randf_range(0.0, 1.0)
		var stream_z: float = lerpf(-248.0, -218.0, t)
		var stream_x: float = lerpf(86.0, 64.0, t) + sin(t * PI) * 4.0
		var side: float = -1.0 if _rng.randf() < 0.5 else 1.0
		var x: float = stream_x + side * _rng.randf_range(2.8, 6.2)
		var z: float = stream_z + _rng.randf_range(-1.5, 1.5)
		var ground: float = _height_at(x, z)
		if ground < 2.0 or ground > 52.0:
			continue
		var size: float = _rng.randf_range(0.25, 0.95)
		downstream_pebbles.append(_make_transform(
			Vector3(x, ground + size * 0.25, z),
			_rng.randf_range(0.0, TAU),
			Vector3(size * 1.5, size * 0.7, size)
		))

	var foam_material := StandardMaterial3D.new()
	foam_material.albedo_color = Color(0.72, 0.86, 0.81, 0.78)
	foam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foam_material.roughness = 0.24
	foam_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_add_multimesh("NorthWaterfallGraniteBasinRim", _rock_mesh, basin_rocks, _rock_material)
	_add_multimesh("NorthWaterfallSprayFoam", _bush_mesh, spray_foam, foam_material)
	_add_multimesh("NorthWaterfallDownstreamPebbles", _rock_mesh, downstream_pebbles, _rock_material)
