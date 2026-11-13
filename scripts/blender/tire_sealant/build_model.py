"""Blender 5.2 headless：建補胎劑噴罐（罐身＋噴頭＋短軟管＋銅接頭）、匯出 FBX、重新匯入驗證、渲染圖示原圖與預覽。
由 build.py 呼叫：blender --background --factory-startup --python build_model.py -- <media> <renders> <here>

座標（Blender，Z 上）：罐子直立，原點在底面中心，單位公尺；model 腳本 scale = 1.0。
尺寸照原版噴罐：HairSpray.fbx（頂點高 13.16 × 節點 1/36 × 腳本 0.4）≈ 高 0.146 m、直徑 0.052 m。
匯出：FBX_SCALE_UNITS＋bake_space_transform，軸 -Z 前／Y 上 → 頂點是公尺、節點是單位矩陣。
"""
import math
import os
import struct
import sys

import bpy
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:]
MEDIA, RENDERS, HERE = ARGS[0], ARGS[1], ARGS[2]
NAME = "MinidoracatAnyCar_TireSealant"
FBX = os.path.join(MEDIA, "models_X", "WorldItems", NAME + ".fbx")
TEXPATH = os.path.join(MEDIA, "textures", "WorldItems", NAME + ".png")
GAME = r"D:/SteamLibrary/steamapps/common/ProjectZomboid/media"

# 與 build.py 相同的貼圖格局
TEX, LABEL, SW_Y, SW = 256, (0, 0, 256, 160), 176, 32
SWATCH = {"dome": 0, "cap": 32, "hose": 64, "brass": 96, "bottom": 128, "nozzle": 160}
SWATCH2_Y = 216

SEG = 12
R = 0.028            # 罐身半徑（直徑 5.6 cm）
BODY_TOP = 0.116


def rect_uv(rect, u, v):
    x0, y0, x1, y1 = rect
    return ((x0 + u * (x1 - x0)) / TEX, 1.0 - (y1 - v * (y1 - y0)) / TEX)


def sw(name, row=SW_Y):
    x = SWATCH.get(name, 0)
    return (x + 6, row + 6, x + SW - 6, row + SW - 6)   # 內縮 6 px，取樣不碰鄰塊


class Mesh:
    """各部件自己的頂點（部件之間是硬邊），部件內共用頂點＋平滑著色；UV 存在每個 loop。"""

    def __init__(self):
        self.verts, self.faces, self.uvs, self.smooth = [], [], [], []

    def add_verts(self, pts):
        base = len(self.verts)
        self.verts += [tuple(p) for p in pts]
        return base

    def face(self, idx, uvs, smooth):
        self.faces.append(list(idx))
        self.uvs.append(list(uvs))
        self.smooth.append(smooth)

    def lathe(self, profile, rect, smooth=True, cx=0.0, cy=0.0, seg=SEG):
        """profile：由下往上的 (半徑, z)；rect 的 u 繞一圈、v 沿 profile。"""
        rings = [self.add_verts([(cx + r * math.cos(2 * math.pi * j / seg), cy + r * math.sin(2 * math.pi * j / seg), z)
                                 for j in range(seg)]) for r, z in profile]
        n = len(profile) - 1
        for k in range(n):
            for j in range(seg):
                j1 = (j + 1) % seg
                a, b, c, d = rings[k] + j, rings[k] + j1, rings[k + 1] + j1, rings[k + 1] + j
                self.face((a, b, c, d), [rect_uv(rect, u, v) for u, v in
                                         ((j / seg, k / n), ((j + 1) / seg, k / n), ((j + 1) / seg, (k + 1) / n), (j / seg, (k + 1) / n))],
                          smooth)
        return rings

    def disc(self, ring, rect, up, seg=SEG):
        idx = [ring + j for j in range(seg)]
        if not up:
            idx.reverse()
        uv = [rect_uv(rect, 0.5 + 0.5 * math.cos(2 * math.pi * (i if up else seg - 1 - i) / seg),
                      0.5 + 0.5 * math.sin(2 * math.pi * (i if up else seg - 1 - i) / seg)) for i in range(seg)]
        self.face(idx, uv, False)

    def box(self, lo, hi, rect):
        (x0, y0, z0), (x1, y1, z1) = lo, hi
        for q in ([(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)],
                  [(x0, y1, z0), (x1, y1, z0), (x1, y0, z0), (x0, y0, z0)],
                  [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)],
                  [(x1, y1, z0), (x0, y1, z0), (x0, y1, z1), (x1, y1, z1)],
                  [(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)],
                  [(x0, y1, z0), (x0, y0, z0), (x0, y0, z1), (x0, y1, z1)]):
            base = self.add_verts(q)
            self.face(range(base, base + 4), [rect_uv(rect, u, v) for u, v in ((0, 0), (1, 0), (1, 1), (0, 1))], False)

    def tube(self, path, r, rect, seg=6):
        """沿 XZ 平面路徑的管子（副法線固定是 +Y）。"""
        y = Vector((0, 1, 0))
        rings = []
        for i, p in enumerate(path):
            p = Vector(p)
            t = (Vector(path[min(i + 1, len(path) - 1)]) - Vector(path[max(i - 1, 0)])).normalized()
            nrm = t.cross(y).normalized()
            rings.append(self.add_verts([p + r * (math.cos(2 * math.pi * j / seg) * nrm + math.sin(2 * math.pi * j / seg) * y)
                                         for j in range(seg)]))
        for k in range(len(path) - 1):
            for j in range(seg):
                j1 = (j + 1) % seg
                # (a,b,c,d) 的法線是 +Y 切向 × t ＝ 朝內，反過來 (a,d,c,b) 才朝外
                a, b, c, d = rings[k] + j, rings[k] + j1, rings[k + 1] + j1, rings[k + 1] + j
                self.face((a, d, c, b), [rect_uv(rect, u, v) for u, v in ((0.2, 0.2), (0.2, 0.8), (0.8, 0.8), (0.8, 0.2))], True)
        return rings

    def build(self, name, image):
        me = bpy.data.meshes.new(name)
        me.from_pydata(self.verts, [], self.faces)
        me.update()
        uv = me.uv_layers.new(name="UVMap")
        for poly, fuv, sm in zip(me.polygons, self.uvs, self.smooth):
            poly.use_smooth = sm
            for k, loop in enumerate(poly.loop_indices):
                uv.data[loop].uv = fuv[k]
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        img = mat.node_tree.nodes.new("ShaderNodeTexImage")
        img.image = image
        img.interpolation = "Closest"
        mat.node_tree.links.new(img.outputs["Color"], bsdf.inputs["Base Color"])
        me.materials.append(mat)
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


def build_can(image):
    m = Mesh()
    # 底：內凹的底面＋斜邊（黑）
    bottom = m.lathe([(0.025, 0.0), (R, 0.004)], sw("band", SWATCH2_Y))
    m.disc(bottom[0], sw("bottom"), up=False)
    m.lathe([(R, 0.004), (R, BODY_TOP)], LABEL)                                    # 罐身標籤
    dome = m.lathe([(R, BODY_TOP), (0.0245, 0.125), (0.016, 0.1315), (0.0125, 0.133)], sw("dome"))
    m.disc(dome[-1], sw("dome"), up=True)
    cap = m.lathe([(0.0115, 0.133), (0.0115, 0.146), (0.0095, 0.148)], sw("cap"))   # 噴頭座
    m.disc(cap[-1], sw("cap"), up=True)
    m.box((0.008, -0.0035, 0.1385), (0.0175, 0.0035, 0.1455), sw("nozzle"))        # 出口接頭（往 +X）
    # 軟管：從接頭出來往下彎，貼著罐身 +X 側垂下
    hose = [(0.016, 0.0, 0.142), (0.024, 0.0, 0.1425), (0.0295, 0.0, 0.138), (0.0322, 0.0, 0.129),
            (0.0326, 0.0, 0.110), (0.0326, 0.0, 0.092)]
    m.tube(hose, 0.004, sw("hose"))
    brass = m.lathe([(0.0055, 0.072), (0.0055, 0.093)], sw("brass"), cx=0.0326, seg=6)   # 氣嘴銅接頭
    m.disc(brass[0], sw("brass"), up=False, seg=6)
    return m.build(NAME, image)


def export(ob):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.fbx(filepath=FBX, use_selection=True, object_types={"MESH"},
                             apply_scale_options="FBX_SCALE_UNITS", bake_space_transform=True,
                             axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE",
                             add_leaf_bones=False, bake_anim=False, path_mode="STRIP")
    print("exported", FBX)


def fbx_unit_scale(path):
    d = open(path, "rb").read()
    i = d.find(b"UnitScaleFactor")
    j = d.find(b"D", i + len(b"UnitScaleFactor") + 30)   # S"double" S"Number" S"" 之後的 D 型別值
    return struct.unpack_from("<d", d, j + 1)[0]


def verify():
    """空場景重新匯入：印節點、bbox、面數；寫 renders/verify.txt。"""
    lines = []
    usf = fbx_unit_scale(FBX)
    lines.append(f"UnitScaleFactor {usf}")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=FBX)
    for ob in bpy.context.scene.objects:
        node = [s / (usf / 100) for s in ob.scale]
        vs = [v.co for v in ob.data.vertices]
        lo = [min(v[i] for v in vs) for i in range(3)]
        hi = [max(v[i] for v in vs) for i in range(3)]
        tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        lines.append(f"object {ob.name} loc {tuple(round(v, 5) for v in ob.location)} rot {tuple(round(v, 4) for v in ob.rotation_euler)} "
                     f"node_scale {tuple(round(v, 5) for v in node)}")
        lines.append(f"local bbox lo {tuple(round(v, 4) for v in lo)} hi {tuple(round(v, 4) for v in hi)}")
        lines.append(f"verts {len(vs)} faces {len(ob.data.polygons)} tris {tris} uv {[u.name for u in ob.data.uv_layers]}")
    with open(os.path.join(RENDERS, "verify.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    for l in lines:
        print("VERIFY", l)


def bbox(obs):
    pts = [o.matrix_world @ v.co for o in obs for v in o.data.vertices]
    return (Vector([min(p[i] for p in pts) for i in range(3)]), Vector([max(p[i] for p in pts) for i in range(3)]))


def render(obs, out, az, el, ortho, res):
    sc = bpy.context.scene
    for o in sc.collection.objects:
        if o.type == "MESH":
            o.hide_render = o not in obs
    # 這台機器的 headless Blender 開不了 GPU context（Workbench 在 DRW_gpu_context_create 當掉），改用 Cycles CPU
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 48
    sc.cycles.use_denoising = False
    if sc.world is None:
        sc.world = bpy.data.worlds.new("World")
    sc.world.color = (0.55, 0.55, 0.55)   # 均勻環境光
    if sc.world.node_tree:
        sc.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.55, 0.55, 1)
    if "Key" not in bpy.data.objects:
        sun = bpy.data.objects.new("Key", bpy.data.lights.new("Key", "SUN"))
        sun.data.energy = 2.5
        sc.collection.objects.link(sun)
    a = math.radians(az - 35)   # 主光從鏡頭左上方
    bpy.data.objects["Key"].rotation_euler = (Vector((math.sin(a), -math.cos(a), 1.2)) * -1).to_track_quat("-Z", "Y").to_euler()
    sc.render.film_transparent = True
    sc.render.resolution_x = sc.render.resolution_y = res
    sc.view_settings.view_transform = "Standard"
    bpy.context.view_layer.update()   # 剛改的 location／scale 要先更新 matrix_world
    lo, hi = bbox(obs)
    target = (lo + hi) / 2
    cd = bpy.data.cameras.new("Cam")
    cd.type = "ORTHO"
    cd.ortho_scale = ortho
    cam = bpy.data.objects.new("Cam", cd)
    sc.collection.objects.link(cam)
    a, e = math.radians(az), math.radians(el)
    cam.location = target + Vector((math.cos(e) * math.sin(a), -math.cos(e) * math.cos(a), math.sin(e))) * 2
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    sc.render.filepath = out
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)


def vanilla_hairspray():
    """原版 HairSpray 照遊戲尺寸擺放：頂點 × 節點 1/36 × 腳本 0.4。"""
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(GAME, "models_X", "WorldItems", "HairSpray.fbx"))
    ob = (set(bpy.context.scene.objects) - before).pop()
    ob.scale = (0.4 / 36,) * 3
    img = bpy.data.images.load(os.path.join(GAME, "textures", "WorldItems", "PaintSprayCan.png"))
    mat = ob.data.materials[0]
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = img
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return ob


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    image = bpy.data.images.load(TEXPATH)
    can = build_can(image)
    export(can)
    verify()

    # 重新匯入後的場景直接拿來渲染（就是遊戲會讀到的那份 FBX）
    image = bpy.data.images.load(TEXPATH)
    can = next(o for o in bpy.context.scene.objects if o.type == "MESH")
    mat = can.data.materials[0]
    mat.use_nodes = True
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = "Closest"
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])

    # 圖示：罐頂朝右上斜放（原版 Item_SprayPaint 的姿勢）
    base = can.matrix_world.copy()
    # 繞視線軸轉，罐頂在畫面上往右倒；鏡頭稍偏 +X，軟管落在左上輪廓線、正面圖案朝鏡頭
    az = -195
    view = Vector((math.sin(math.radians(az)), -math.cos(math.radians(az)), 0))
    can.matrix_world = Matrix.Rotation(math.radians(-50), 4, view) @ base
    render([can], os.path.join(RENDERS, "icon.png"), az=az, el=0, ortho=0.2, res=256)
    can.matrix_world = base

    # 預覽：PZ 鏡頭（方位 45°、仰角 30°）與另一側低角度，左邊擺原版噴漆罐對照尺寸
    van = vanilla_hairspray()
    van.location = (-0.085, 0.0, 0.0)
    render([can, van], os.path.join(HERE, "preview-model-pz.png"), az=45, el=30, ortho=0.24, res=640)
    render([can], os.path.join(HERE, "preview-model-side.png"), az=-160, el=12, ortho=0.18, res=640)
    render([can], os.path.join(HERE, "preview-model-front.png"), az=-20, el=20, ortho=0.18, res=640)
    print("BUILD OK")


main()
