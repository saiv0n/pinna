# Uygulamadaki kulaklık ve kutu görsellerini üretir.
# Model: "AirPods Pro", Jed Falcone, CC-BY 4.0, https://sketchfab.com/3d-models/3f84ddc3d87a4ec0a5e5f379abfecd9c
# Modelin kendisi repoda yok, Sketchfab'den indirilen fbx'in yolu verilir.
#
# blender -b -P art/render.py -- <fbx> <çıktı klasörü> [örnek sayısı] [bud|set|all]
import bpy
import bmesh
import math
import os
import sys
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
FBX = os.path.abspath(argv[0])
OUT = os.path.abspath(argv[1])
SAMPLES = int(argv[2]) if len(argv) > 2 else 512
WHICH = argv[3] if len(argv) > 3 else "all"
os.makedirs(OUT, exist_ok=True)

# fbx içindeki iki kulaklık x ekseninde bu değerin iki yanında duruyor
MID_X = 1.43


def scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    s.render.engine = "CYCLES"
    s.cycles.samples = SAMPLES
    s.cycles.use_denoising = True
    s.cycles.max_bounces = 16
    s.cycles.glossy_bounces = 8
    s.render.film_transparent = True
    s.view_settings.view_transform = "AgX"
    s.view_settings.look = "AgX - Base Contrast"
    s.view_settings.exposure = 0.15
    s.render.image_settings.file_format = "PNG"
    s.render.image_settings.color_mode = "RGBA"
    prefs = bpy.context.preferences.addons["cycles"].preferences
    for kind in ("OPTIX", "CUDA"):
        try:
            prefs.compute_device_type = kind
            prefs.get_devices()
            if any(d.type == kind for d in prefs.devices):
                for d in prefs.devices:
                    d.use = d.type == kind
                s.cycles.device = "GPU"
                break
        except TypeError:
            continue
    studio_world(s)
    return s


def studio_world(s):
    # yansımalarda stüdyo havası olsun diye yukarısı açık, aşağısı koyu bir gradyan
    w = bpy.data.worlds.new("studio")
    s.world = w
    w.use_nodes = True
    nt = w.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    bg = nt.nodes.new("ShaderNodeBackground")
    coord = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    mapr = nt.nodes.new("ShaderNodeMapRange")
    mapr.inputs["From Min"].default_value = -1
    mapr.inputs["From Max"].default_value = 1
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.35
    ramp.color_ramp.elements[0].color = (0.28, 0.29, 0.31, 1)
    ramp.color_ramp.elements[1].position = 0.75
    ramp.color_ramp.elements[1].color = (1.0, 1.0, 1.0, 1)
    nt.links.new(coord.outputs["Normal"], sep.inputs[0])
    nt.links.new(sep.outputs["Z"], mapr.inputs["Value"])
    nt.links.new(mapr.outputs["Result"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 0.9
    nt.links.new(bg.outputs[0], out.inputs[0])


def principled(name, color, rough, coat=0.0, coat_rough=0.05, metal=0.0, sss=0.0, spec=0.5):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    p.inputs["Specular IOR Level"].default_value = spec
    p.inputs["Coat Weight"].default_value = coat
    p.inputs["Coat Roughness"].default_value = coat_rough
    if sss:
        p.inputs["Subsurface Weight"].default_value = sss
        p.inputs["Subsurface Radius"].default_value = (1.0, 0.9, 0.8)
        p.inputs["Subsurface Scale"].default_value = 0.08
    return m


def materials():
    return {
        # Apple'ın beyazı: saf beyaza yakın, üstünde ince vernik parlaklığı
        "shell": principled("shell", (0.92, 0.92, 0.925), 0.22, coat=0.6, coat_rough=0.06, sss=0.06),
        "tip": principled("tip", (0.86, 0.865, 0.87), 0.48, sss=0.35, spec=0.35),
        "black": principled("black", (0.012, 0.012, 0.014), 0.42, spec=0.4),
        "mesh": principled("mesh", (0.03, 0.03, 0.035), 0.6, metal=0.4),
        "steel": principled("steel", (0.86, 0.86, 0.88), 0.18, metal=1.0),
        "hinge": principled("hinge", (0.72, 0.73, 0.75), 0.25, metal=1.0),
        "port": principled("port", (0.05, 0.05, 0.055), 0.35),
        "led": principled("led", (0.06, 0.07, 0.065), 0.25),
    }


# fbx malzeme adı ile bizim malzememiz arasındaki eşleme
MAP_BUD = {"Mat.1": "shell", "Mat.2": "tip", "Mat.3": "black", "Speaker Grille": "mesh", "Mat.9": "steel", None: "black"}
MAP_CASE = {"Mat.1": "shell", "Mat.5": "hinge", "Mat.10": "port", "Mat.4": "led", None: "shell"}


def import_model():
    bpy.ops.import_scene.fbx(filepath=FBX)
    for o in list(bpy.data.objects):
        if o.type in ("CAMERA", "LIGHT"):
            bpy.data.objects.remove(o)


def root_of(o):
    while o.parent:
        o = o.parent
    return o.name


def apply_world(o):
    mw = o.matrix_world.copy()
    o.parent = None
    o.data.transform(mw)
    o.matrix_world = Matrix.Identity(4)


def retarget(o, mapping, M):
    if not o.material_slots:
        o.data.materials.append(M[mapping[None]])
        return
    for slot in o.material_slots:
        key = slot.material.name if slot.material else None
        slot.material = M[mapping.get(key, mapping[None])]


def smooth(o):
    for p in o.data.polygons:
        p.use_smooth = True
    try:
        o.data.set_sharp_from_angle(angle=math.radians(40))
    except AttributeError:
        pass


def bounds(objs):
    pts = [v.co for o in objs for v in o.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def right_bud(M):
    """Sağ kulaklığın parçalarını ayırır; sol kulaklığın sapı modelde eksik olduğu için onu kullanmıyoruz."""
    parts = [o for o in bpy.data.objects if o.type == "MESH" and root_of(o) == "Airpods"]
    keep = []
    for o in parts:
        apply_world(o)
        bm = bmesh.new()
        bm.from_mesh(o.data)
        drop = [v for v in bm.verts if v.co.x < MID_X]
        bmesh.ops.delete(bm, geom=drop, context="VERTS")
        bm.to_mesh(o.data)
        bm.free()
        if len(o.data.vertices) == 0:
            bpy.data.objects.remove(o)
            continue
        retarget(o, MAP_BUD, M)
        smooth(o)
        keep.append(o)
    lo, hi = bounds(keep)
    c = (lo + hi) / 2
    pivot = bpy.data.objects.new("bud", None)
    bpy.context.collection.objects.link(pivot)
    for o in keep:
        o.data.transform(Matrix.Translation(-c))
        o.parent = pivot
    return pivot, hi - lo


def drop_rest(keep):
    for o in list(bpy.data.objects):
        top = o
        while top.parent:
            top = top.parent
        if top.name not in keep:
            bpy.data.objects.remove(o)


def softbox(name, loc, size, power, target, size_y=None):
    d = bpy.data.lights.new(name, "AREA")
    d.shape = "RECTANGLE"
    d.size = size
    d.size_y = size_y or size
    d.energy = power
    o = bpy.data.objects.new(name, d)
    o.location = loc
    bpy.context.collection.objects.link(o)
    c = o.constraints.new("TRACK_TO")
    c.target = target
    return o


def lights(center, s):
    t = bpy.data.objects.new("target", None)
    t.location = center
    bpy.context.collection.objects.link(t)
    # büyük üst softbox beyazı taşır, yanlar kenarlarda uzun parlak şeritler çizer
    softbox("top", center + Vector((0, -0.6, 4.5)) * s, 6 * s, 900 * s * s, t, 4 * s)
    softbox("left", center + Vector((-4.2, -2.6, 1.2)) * s, 1.4 * s, 380 * s * s, t, 6 * s)
    softbox("right", center + Vector((4.4, -1.8, 0.8)) * s, 1.2 * s, 300 * s * s, t, 6 * s)
    softbox("front", center + Vector((0.6, -6, 0.4)) * s, 7 * s, 160 * s * s, t, 3 * s)
    softbox("rim", center + Vector((-1.5, 4.5, 2.5)) * s, 3 * s, 420 * s * s, t)


def camera(loc, look, lens, res):
    s = bpy.context.scene
    s.render.resolution_x, s.render.resolution_y = res
    cam = bpy.data.cameras.new("cam")
    cam.lens = lens
    o = bpy.data.objects.new("cam", cam)
    bpy.context.collection.objects.link(o)
    o.location = loc
    t = bpy.data.objects.new("camtarget", None)
    t.location = look
    bpy.context.collection.objects.link(t)
    c = o.constraints.new("TRACK_TO")
    c.target = t
    s.camera = o


def render(name):
    bpy.context.scene.render.filepath = os.path.join(OUT, name)
    bpy.ops.render.render(write_still=True)
    print("yazıldı:", name)


def duplicate(pivot, name):
    new = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(new)
    for ch in pivot.children:
        d = ch.copy()
        d.data = ch.data.copy()
        bpy.context.collection.objects.link(d)
        d.parent = new
    return new


def render_bud():
    scene()
    M = materials()
    import_model()
    bud, size = right_bud(M)
    drop_rest({"bud"})
    bud.rotation_euler = (math.radians(3), 0, math.radians(-14))
    h = size.z
    lights(Vector((0, 0, 0)), h / 3.6)
    camera(Vector((0, -h * 5.2, h * 0.55)), Vector((0, 0, -h * 0.02)), 85, (1000, 1400))
    render("bud.png")


def render_pair():
    """İki kulaklık yan yana, kulak uçları birbirine dönük; bağlantı ekranı ve açılır kart için.
    Modelin kutusunun önünde simetriden kalma bir girinti olduğu için kutuyu göstermiyoruz."""
    scene()
    M = materials()
    import_model()
    right, size = right_bud(M)
    drop_rest({"bud"})
    left = duplicate(right, "budL")
    left.scale = (-1, 1, 1)
    gap = size.x * 0.62
    right.location = (gap, 0, 0)
    right.rotation_euler = (math.radians(3), 0, math.radians(-14))
    left.location = (-gap, 0.15 * size.x, 0)
    left.rotation_euler = (math.radians(3), 0, math.radians(14))
    h = size.z
    lights(Vector((0, 0, 0)), h / 3.2)
    camera(Vector((0, -h * 6.0, h * 0.7)), Vector((0, 0, -h * 0.03)), 85, (1600, 1300))
    render("set.png")


if WHICH in ("all", "bud"):
    render_bud()
if WHICH in ("all", "set"):
    render_pair()
