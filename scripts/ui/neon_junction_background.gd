extends Control
## First production background study. No campaign/save/menu actions are replaced.
## Art coordinates use the unmodified fal plate; scale is shared by every layer.
const PLATE_PATH := "res://assets/art/ui/main_menu/neon_junction/city_plate.png"
const METRO_PATH := "res://assets/art/ui/main_menu/neon_junction/metro.png"
const PLATE_SIZE := Vector2(2752.0, 1536.0)
const TRAIN_WIDTH := 920.0
const TRAIN_BOTTOM := 956.0
const CROSSING_SECONDS := 8.0
const CYCLE_SECONDS := 27.0
# Highest city silhouettes in plate pixels; used only by the sky treatment.
# Repeated x values express vertical building edges.
const SKYLINE := [
    Vector2(0,0), Vector2(607,0), Vector2(622,260),
    Vector2(632,243), Vector2(638,195), Vector2(650,176),
    Vector2(654,148), Vector2(660,171), Vector2(675,229),
    Vector2(688,247), Vector2(688,285), Vector2(716,285),
    Vector2(716,225), Vector2(749,219), Vector2(753,205),
    Vector2(762,221), Vector2(774,221), Vector2(784,157),
    Vector2(790,157), Vector2(800,221), Vector2(809,220),
    Vector2(809,98), Vector2(830,98), Vector2(830,52),
    Vector2(849,52), Vector2(849,41), Vector2(900,41),
    Vector2(912,9), Vector2(920,9), Vector2(922,51),
    Vector2(941,51), Vector2(947,29), Vector2(952,29),
    Vector2(956,52), Vector2(971,54), Vector2(971,92),
    Vector2(985,92), Vector2(985,326), Vector2(1005,340),
    Vector2(1027,354), Vector2(1027,487), Vector2(1061,479),
    Vector2(1065,445), Vector2(1069,479), Vector2(1081,461),
    Vector2(1088,464), Vector2(1089,483), Vector2(1118,497),
    Vector2(1136,514), Vector2(1136,590), Vector2(1157,590),
    Vector2(1157,620), Vector2(1586,620), Vector2(1598,552),
    Vector2(1606,620), Vector2(1630,620), Vector2(1630,454),
    Vector2(1645,428), Vector2(1645,379), Vector2(1653,379),
    Vector2(1656,425), Vector2(1670,420), Vector2(1671,414),
    Vector2(1695,428), Vector2(1740,428), Vector2(1740,185),
    Vector2(1752,180), Vector2(1768,157), Vector2(1777,156),
    Vector2(1779,121), Vector2(1785,121), Vector2(1786,157),
    Vector2(1798,172), Vector2(1804,142), Vector2(1810,142),
    Vector2(1812,179), Vector2(1835,181), Vector2(1835,331),
    Vector2(1875,331), Vector2(1885,273), Vector2(1893,298),
    Vector2(1893,331), Vector2(1911,331), Vector2(1911,176),
    Vector2(1938,142), Vector2(1951,130), Vector2(1959,137),
    Vector2(1965,137), Vector2(1965,111), Vector2(1975,100),
    Vector2(1978,34), Vector2(1984,34), Vector2(1987,104),
    Vector2(1995,112), Vector2(1995,133), Vector2(2004,109),
    Vector2(2023,100), Vector2(2055,100), Vector2(2055,62),
    Vector2(2063,62), Vector2(2063,96), Vector2(2097,96),
    Vector2(2097,140), Vector2(2110,138), Vector2(2110,181),
    Vector2(2164,181), Vector2(2200,165), Vector2(2220,164),
    Vector2(2220,117), Vector2(2250,96), Vector2(2286,96),
    Vector2(2286,51), Vector2(2294,51), Vector2(2294,92),
    Vector2(2370,82), Vector2(2370,0), Vector2(2752,0)
]
@export var night_sky_enabled := true
@export var smoke_motion_enabled := true
@export var motion_enabled := true
@export var show_preview_help := false
var elapsed := 0.0
var _stage: Node2D
var _train: Sprite2D
var _sign_material: ShaderMaterial
var _help: Label

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    var plate := load(PLATE_PATH) as Texture2D
    var metro := load(METRO_PATH) as Texture2D
    _stage = Node2D.new()
    _stage.name = "CityLayers"
    add_child(_stage)
    var background := Sprite2D.new()
    background.name = "CityPlate"
    background.texture = plate
    background.centered = false
    _sign_material = ShaderMaterial.new()
    _sign_material.shader = load("res://shaders/neon_junction_signs.gdshader")
    _sign_material.set_shader_parameter("skyline_height", _make_skyline_texture())
    _sign_material.set_shader_parameter("clean_city", load("res://assets/art/ui/main_menu/neon_junction/city_no_steam.png"))
    background.material = _sign_material
    _stage.add_child(background)
    _train = Sprite2D.new()
    _train.name = "PassingMetro"
    _train.texture = metro
    _train.centered = false
    _train.scale = Vector2.ONE * (TRAIN_WIDTH / float(metro.get_width()))
    _train.modulate = Color(0.80, 0.86, 1.0, 1.0)
    _stage.add_child(_train)
    # Sample the original plate for occlusion, so there are no re-painted seams.
    # Main deck, front guardrail and its posts sit in front of the moving vehicle.
    _add_cover(plate, Rect2(0, 955, 2752, 25), "BridgeDeck")
    _add_cover(plate, Rect2(335, 910, 2043, 9), "FrontGuardrail")
    # Source-pixel foreground cores, checked against the clean plate.
    # The stepped lamp shapes exclude the scenery between their brackets.
    var foreground_cores: Array[Rect2] = [
        Rect2(438,918,9,37),
        Rect2(514,918,7,37),
        Rect2(619,918,8,37),
        Rect2(723,918,10,37),
        Rect2(851,918,8,37),
        Rect2(925,918,9,37),
        Rect2(998,918,9,37),
        Rect2(1071,918,8,37),
        Rect2(1144,918,8,37),
        Rect2(1216,918,9,37),
        Rect2(1290,918,8,37),
        Rect2(1418,918,8,37),
        Rect2(1491,918,7,37),
        Rect2(1564,918,8,37),
        Rect2(1637,918,8,37),
        Rect2(1704,918,7,37),
        Rect2(1779,918,7,37),
        Rect2(1850,918,7,37),
        Rect2(1923,918,7,37),
        Rect2(1996,918,8,37),
        Rect2(2069,918,7,37),
        Rect2(2143,918,7,37),
        Rect2(2338,923,5,32),
        Rect2(786,855,9,31),
        Rect2(778,886,29,6),
        Rect2(771,892,42,15),
        Rect2(776,907,35,48),
        Rect2(1357,855,8,31),
        Rect2(1348,886,26,5),
        Rect2(1342,891,37,17),
        Rect2(1346,908,31,47),
        Rect2(2179,852,25,40),
        Rect2(2169,858,4,32),
        Rect2(2170,892,37,25),
        Rect2(2172,917,33,38),
        Rect2(543,861,27,94)
    ]
    for i in foreground_cores.size():
        _add_cover(plate, foreground_cores[i], "RailPost%d" % i)
    _add_cover(plate, Rect2(0,800,413,185), "LeftEntryOccluder")
    _add_cover(plate, Rect2(2390,800,362,185), "RightExitOccluder")
    _help = Label.new()
    _help.name = "PreviewHelp"
    _help.text = "NEON JUNCTION / BACKGROUND STUDY     SPACE  Still / motion     B  Before / night sky     S  Smoke     H  Hide help     ESC  Close preview"
    _help.add_theme_font_size_override("font_size", 15)
    _help.add_theme_color_override("font_shadow_color", Color.BLACK)
    _help.add_theme_constant_override("shadow_offset_x", 2)
    _help.add_theme_constant_override("shadow_offset_y", 2)
    _help.position = Vector2(24,24)
    _help.visible = show_preview_help
    add_child(_help)
    resized.connect(_fit)
    _fit()
    _update_animation()

func _make_skyline_texture() -> ImageTexture:
    var mask := Image.create(int(PLATE_SIZE.x), 1, false, Image.FORMAT_RF)
    var segment := 0
    for x in int(PLATE_SIZE.x):
        while segment < SKYLINE.size() - 2 and SKYLINE[segment + 1].x <= float(x):
            segment += 1
        var left: Vector2 = SKYLINE[segment]
        var right: Vector2 = SKYLINE[segment + 1]
        var weight := clampf((float(x) - left.x) / maxf(1.0, right.x - left.x), 0.0, 1.0)
        var height := lerpf(left.y, right.y, weight)
        mask.set_pixel(x, 0, Color(height / PLATE_SIZE.y, 0, 0, 1))
    return ImageTexture.create_from_image(mask)

func set_smoke_motion_enabled(enabled: bool) -> void:
    smoke_motion_enabled = enabled
    _update_animation()

func set_night_sky_enabled(enabled: bool) -> void:
    night_sky_enabled = enabled
    _update_animation()

func _add_cover(plate: Texture2D, region: Rect2, node_name: String) -> void:
    var cover := Sprite2D.new()
    cover.name = node_name
    cover.texture = plate
    cover.centered = false
    cover.region_enabled = true
    cover.region_rect = region
    cover.region_filter_clip_enabled = true
    cover.position = region.position
    _stage.add_child(cover)

func _fit() -> void:
    if not is_instance_valid(_stage):
        return
    var factor := maxf(size.x / PLATE_SIZE.x, size.y / PLATE_SIZE.y)
    _stage.scale = Vector2.ONE * factor
    _stage.position = ((size - PLATE_SIZE * factor) * 0.5).round()

func _process(delta: float) -> void:
    if not is_visible_in_tree():
        return
    if motion_enabled:
        elapsed += delta
    _update_animation()

func _update_animation() -> void:
    if not is_instance_valid(_train):
        return
    _sign_material.set_shader_parameter("animation_time", elapsed)
    _sign_material.set_shader_parameter("animate_signs", motion_enabled)
    _sign_material.set_shader_parameter("night_sky_enabled", night_sky_enabled)
    _sign_material.set_shader_parameter("smoke_motion_enabled", smoke_motion_enabled)
    var phase := fposmod(elapsed + 2.0, CYCLE_SECONDS)
    _train.visible = motion_enabled and phase < CROSSING_SECONDS
    var x := lerpf(-TRAIN_WIDTH, PLATE_SIZE.x, phase / CROSSING_SECONDS)
    _train.position = Vector2(roundf(x),roundf(TRAIN_BOTTOM - float(_train.texture.get_height()) * _train.scale.y))

func set_preview_time(seconds: float) -> void:
    elapsed = maxf(0.0, seconds)
    _update_animation()
