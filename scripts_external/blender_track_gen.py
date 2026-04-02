import bpy
import math
import mathutils

# =============================================================================
# TRACK PARAMETERS & SEQUENCE
# =============================================================================

TRACK_WIDTH = 22.0
ASTRO_WIDTH = 2.0
BARRIER_WIDTH = 2.0
BARRIER_HEIGHT = 1.0
SEGMENT_LENGTH = 1.0

# Rounded Corner parameters for the barriers
BARRIER_RADIUS = 0.2
BARRIER_RES = 5

COLOR_ASPHALT = (0.5, 0.5, 0.5)
COLOR_TURF = (0.05, 0.25, 0.05)
COLOR_BARRIER = (0.10, 0.10, 0.10)
COLOR_BOOST = (0.5, 0.5, 0.0)
COLOR_CHECKPOINT = (0.10, 0.10, 0.10)

TRACK_SEQUENCE = [
    "checkpoint", "decline", "straight", "incline", "straight",
    "1x1_right", "1x1_left", "straight", "1x1_left", "checkpoint",
    "1x1_left", "1x1_right", "1x1_left", "1x1_left", "1x1_right",
    "1x1_right", "straight", "straight", "straight", "straight",
    "incline", "1x1_right", "1x1_left", "1x1_left", "2x2_right",
    "boost", "straight", "straight", "straight", "straight",
    "straight", "1x1_left", "checkpoint", "1x1_left", "straight",
    "straight", "straight", "straight", "straight", "straight",
    "straight", "straight", "straight", "incline", "1x1_left",
    "1x1_right", "1x1_right", "1x1_left", "1x1_right", "1x1_right",
    "1x1_left", "1x1_right", "1x1_right", "1x1_left", "straight",
    "1x1_left", "straight", "checkpoint", "straight", "straight",
    "3x3_right", "straight", "incline", "straight", "straight",
    "straight", "1x1_right", "1x1_left", "1x1_left", "1x1_right",
    "2x2_left", "1x1_right", "1x1_left", "1x1_left", "1x1_right",
    "checkpoint", "straight", "1x1_left", "straight", "straight",
    "scurve_left", "scurve_right", "incline", "straight", "1x1_right",
    "1x1_left", "2x2_left", "1x1_left", "1x1_right", "straight",
    "1x1_right", "checkpoint", "boost", "incline", "straight",
    "decline", "straight", "straight", "3x3_left", "3x3_left",
    "2x2_right", "straight"
]

PIECE_DEFS = {
    "straight":   ("STRAIGHT", 32.0, 0.0, False),
    "checkpoint": ("CHECKPOINT", 32.0, 0.0, False),
    "boost":      ("BOOST", 32.0, 0.0, False),
    "decline":    ("VERTICAL", 64.0, -8.0, False),
    "incline":    ("VERTICAL", 64.0, 8.0, False),
    "1x1_left":   ("HORIZONTAL", 16.0, 90.0, False),
    "1x1_right":  ("HORIZONTAL", 16.0, 90.0, True),
    "2x2_left":   ("HORIZONTAL", 48.0, 90.0, False),
    "2x2_right":  ("HORIZONTAL", 48.0, 90.0, True),
    "3x3_left":   ("HORIZONTAL", 80.0, 90.0, False),
    "3x3_right":  ("HORIZONTAL", 80.0, 90.0, True),
    "scurve_left": ("SCURVE", 64.0, 32.0, False),
    "scurve_right":("SCURVE", 64.0, -32.0, False),
}

# =============================================================================
# MATH ENGINES (Decoupled 2D Grid + 3D Elevation Tracking)
# =============================================================================

def angle_from_height(length, height):
    if abs(height) < 1e-9: return 0.0
    h, L, theta = abs(height), length, abs(height)/length
    for _ in range(50):
        f = (L / theta) * (1.0 - math.cos(theta)) - h
        df = L / theta**2 * (theta * math.sin(theta) - (1.0 - math.cos(theta)))
        theta -= f / df
        if abs(f) < 1e-10: break
    return math.copysign(math.degrees(theta), height)

def get_matrix_at_t(p_type, p1, p2, p3, t):
    if p_type in ["STRAIGHT", "CHECKPOINT", "BOOST"]:
        return mathutils.Matrix.Translation((p1 * t, 0, 0))
    elif p_type == "VERTICAL":
        length, height = p1, p2
        if abs(height) < 1e-9: return mathutils.Matrix.Translation((length * t, 0, 0))
        theta_rad = math.radians(abs(angle_from_height(length, height)))
        radius = length / theta_rad
        current_theta = theta_rad * t
        cx = radius * math.sin(current_theta)
        cz = math.copysign(radius * (1.0 - math.cos(current_theta)), height)
        pitch = current_theta * math.copysign(1.0, height)
        loc = mathutils.Vector((cx, 0.0, cz))
        return mathutils.Matrix.Translation(loc) @ mathutils.Matrix.Rotation(-pitch, 4, 'Y')
    elif p_type == "HORIZONTAL":
        radius, angle_deg, is_right = p1, p2, p3
        current_rad = math.radians(abs(angle_deg)) * t
        loc = mathutils.Vector((radius * math.sin(current_rad), radius * (1.0 - math.cos(current_rad)), 0.0))
        mat = mathutils.Matrix.Translation(loc) @ mathutils.Matrix.Rotation(current_rad, 4, 'Z')
        if is_right:
            sy = mathutils.Matrix.Scale(-1, 4, (0,1,0))
            mat = sy @ mat @ sy
        return mat

def get_2d_at_t(gx, gy, gyaw, p_type, p1, p2, p3, t):
    if p_type in ["STRAIGHT", "CHECKPOINT", "BOOST", "VERTICAL"]:
        L = p1 * t
        rad = math.radians(gyaw)
        return gx + L * math.cos(rad), gy + L * math.sin(rad), gyaw
    elif p_type == "HORIZONTAL":
        R, angle, is_right = p1, p2, p3
        sign = -1.0 if is_right else 1.0
        start_rad = math.radians(gyaw)
        cx = gx - sign * R * math.sin(start_rad)
        cy = gy + sign * R * math.cos(start_rad)
        nyaw = gyaw + sign * angle * t
        new_rad = math.radians(nyaw)
        return cx + sign * R * math.sin(new_rad), cy - sign * R * math.cos(new_rad), nyaw
    return gx, gy, gyaw

def get_sweeper_matrix(eval_mat, gx, gy, gyaw):
    z = eval_mat.translation.z

    F = eval_mat @ mathutils.Vector((1,0,0)) - eval_mat.translation
    if F.length < 1e-9: F = mathutils.Vector((1,0,0))
    else: F.normalize()

    yaw_rad = math.radians(gyaw)
    g_dx, g_dy = math.cos(yaw_rad), math.sin(yaw_rad)

    d_xy = math.hypot(F.x, F.y)
    pitch_angle = math.atan2(F.z, d_xy)

    tangent = mathutils.Vector((g_dx * math.cos(pitch_angle), g_dy * math.cos(pitch_angle), math.sin(pitch_angle))).normalized()
    base_left = mathutils.Vector((0,0,1)).cross(tangent).normalized()
    base_up = tangent.cross(base_left).normalized()

    left_3d = (eval_mat @ mathutils.Vector((0,1,0)) - eval_mat.translation).normalized()
    tilt = math.atan2(left_3d.dot(base_up), left_3d.dot(base_left))

    real_left = (base_left * math.cos(tilt) + base_up * math.sin(tilt)).normalized()
    real_up = tangent.cross(real_left).normalized()

    mat = mathutils.Matrix.Identity(4)
    mat[0][0], mat[1][0], mat[2][0] = tangent.x, tangent.y, tangent.z
    mat[0][1], mat[1][1], mat[2][1] = real_left.x, real_left.y, real_left.z
    mat[0][2], mat[1][2], mat[2][2] = real_up.x, real_up.y, real_up.z
    mat.translation = mathutils.Vector((gx, gy, z))
    return mat

# =============================================================================
# MESH GENERATOR (Procedural Sweep)
# =============================================================================

def create_material(name, rgb_color):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    mat.diffuse_color = (*rgb_color, 1.0)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*rgb_color, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.9
    return mat

def build_track():
    for obj in list(bpy.data.objects): bpy.data.objects.remove(obj, do_unlink=True)
    for mat in list(bpy.data.materials): bpy.data.materials.remove(mat, do_unlink=True)

    m_asphalt = create_material("Asphalt", COLOR_ASPHALT)
    m_turf = create_material("Turf", COLOR_TURF)
    m_barrier = create_material("Barrier", COLOR_BARRIER)
    m_boost = create_material("Boost", COLOR_BOOST)
    m_check = create_material("Checkpoint", COLOR_CHECKPOINT)

    t_half = TRACK_WIDTH / 2.0
    a_out = TRACK_WIDTH / 2.0 + ASTRO_WIDTH
    b_out = TRACK_WIDTH / 2.0 + ASTRO_WIDTH + BARRIER_WIDTH
    h, d = BARRIER_HEIGHT, -0.5
    r, res = BARRIER_RADIUS, BARRIER_RES

    # --- PROCEDURAL CROSS-SECTION PROFILE ---
    # Built as a SINGLE unbroken ribbon from Left to Right

    profile_verts = []
    profile_mats = []

    # 1. Left Barrier Outer Wall (Bottom)
    profile_verts.append((b_out, d))

    # 2. Left Barrier Outer Top Corner (0 to 90 deg)
    for i in range(res + 1):
        a = math.radians(90 * i / res)
        profile_verts.append((b_out - r + r * math.cos(a), h - r + r * math.sin(a)))
        profile_mats.append(2)

    # 3. Left Barrier Inner Top Corner (90 to 180 deg)
    for i in range(res + 1):
        a = math.radians(90 + 90 * i / res)
        profile_verts.append((a_out + r + r * math.cos(a), h - r + r * math.sin(a)))
        profile_mats.append(2)

    # 4. Drop to turf
    profile_verts.append((a_out, 0))
    profile_mats.append(2)

    # 5. Across Left Turf
    profile_verts.append((t_half, 0))
    profile_mats.append(1)

    # 6. Across Asphalt
    profile_verts.append((-t_half, 0))
    profile_mats.append(0)

    # 7. Across Right Turf
    profile_verts.append((-a_out, 0))
    profile_mats.append(1)

    # 8. Up to Right Barrier Inner Corner
    profile_verts.append((-a_out, h - r))
    profile_mats.append(2)

    # 9. Right Barrier Inner Corner (0 to 90 deg)
    for i in range(1, res + 1):
        a = math.radians(90 * i / res)
        profile_verts.append((-a_out - r + r * math.cos(a), h - r + r * math.sin(a)))
        profile_mats.append(2)

    # 10. Right Barrier Outer Corner (90 to 180 deg)
    for i in range(res + 1):
        a = math.radians(90 + 90 * i / res)
        profile_verts.append((-b_out + r + r * math.cos(a), h - r + r * math.sin(a)))
        profile_mats.append(2)

    # 11. Drop to outer bottom
    profile_verts.append((-b_out, d))
    profile_mats.append(2)


    verts, faces, face_mats = [], [], []
    boost_verts, boost_faces, boost_face_mats = [], [], []
    check_verts, check_faces, check_face_mats = [], [], []

    def write_ring(target_verts, matrix, profile, z_offset=0.0):
        start_idx = len(target_verts)
        for y, z in profile: target_verts.append(matrix @ mathutils.Vector((0, y, z + z_offset)))
        return start_idx

    def write_faces(target_faces, target_mats, prev_start, curr_start, p_mats, mat_override=None):
        for i, m_idx in enumerate(p_mats):
            if m_idx == -1: continue
            target_faces.append((prev_start + i, prev_start + i + 1, curr_start + i + 1, curr_start + i))
            target_mats.append(mat_override if mat_override is not None else m_idx)

    # State Globals
    gx, gy, gyaw = 0.0, 0.0, 0.0
    curr_mat = mathutils.Matrix.Identity(4)
    prev_main_ring = write_ring(verts, get_sweeper_matrix(curr_mat, gx, gy, gyaw), profile_verts)

    for piece_name in TRACK_SEQUENCE:
        if piece_name not in PIECE_DEFS: continue

        sub_pieces = []
        p_type, p1, p2, p3 = PIECE_DEFS[piece_name]
        if p_type in ["STRAIGHT", "CHECKPOINT", "BOOST", "VERTICAL", "HORIZONTAL"]:
            sub_pieces.append((p_type, p1, p2, p3))
        elif p_type == "SCURVE":
            forward, shift = p1, p2
            theta = 2.0 * math.atan2(abs(shift), forward)
            R = (forward**2 + shift**2) / (4.0 * abs(shift))
            sub_pieces.append(("HORIZONTAL", R, math.degrees(theta), shift < 0))
            sub_pieces.append(("HORIZONTAL", R, math.degrees(theta), not (shift < 0)))

        is_boost, is_check = (piece_name == "boost"), (piece_name == "checkpoint")

        for sp_type, sp1, sp2, sp3 in sub_pieces:
            arc_length = sp1 * math.radians(abs(sp2)) if sp_type == "HORIZONTAL" else sp1
            steps = max(1, int(arc_length / SEGMENT_LENGTH))

            start_x, start_y, start_yaw = gx, gy, gyaw

            if is_boost:
                # Flipped winding to face UP
                prev_boost_ring = write_ring(boost_verts, get_sweeper_matrix(curr_mat, gx, gy, gyaw), [(t_half, 0.05), (-t_half, 0.05)])

            for i in range(1, steps + 1):
                t = i / steps

                eval_x, eval_y, eval_yaw = get_2d_at_t(start_x, start_y, start_yaw, sp_type, sp1, sp2, sp3, t)
                eval_mat = curr_mat @ get_matrix_at_t(sp_type, sp1, sp2, sp3, t)
                world_mat = get_sweeper_matrix(eval_mat, eval_x, eval_y, eval_yaw)

                curr_main_ring = write_ring(verts, world_mat, profile_verts)
                write_faces(faces, face_mats, prev_main_ring, curr_main_ring, profile_mats)
                prev_main_ring = curr_main_ring

                if is_boost:
                    # Flipped winding to face UP
                    curr_boost_ring = write_ring(boost_verts, world_mat, [(t_half, 0.05), (-t_half, 0.05)])
                    write_faces(boost_faces, boost_face_mats, prev_boost_ring, curr_boost_ring, [0])
                    prev_boost_ring = curr_boost_ring

                if is_check:
                    mid = steps // 2
                    if i == mid - 1:
                        prev_check_ring = write_ring(check_verts, world_mat, [(t_half, 0.05), (-t_half, 0.05)])
                    elif mid <= i < mid + 2:
                        curr_check_ring = write_ring(check_verts, world_mat, [(t_half, 0.05), (-t_half, 0.05)])
                        write_faces(check_faces, check_face_mats, prev_check_ring, curr_check_ring, [0])
                        prev_check_ring = curr_check_ring

            gx, gy, gyaw = get_2d_at_t(start_x, start_y, start_yaw, sp_type, sp1, sp2, sp3, 1.0)
            curr_mat = curr_mat @ get_matrix_at_t(sp_type, sp1, sp2, sp3, 1.0)

    # Compile Final Objects
    def create_obj(name, v, f, fm, materials):
        if not v: return
        mesh = bpy.data.meshes.new(name + "_Mesh")
        mesh.from_pydata(v, [], f)
        for mat in materials: mesh.materials.append(mat)
        for poly, m_idx in zip(mesh.polygons, fm):
            poly.material_index = m_idx
            poly.use_smooth = True
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)

        # Because it's a perfectly open manifold sheet now, we can safely weld seams and calculate normals!
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.mesh.remove_doubles(threshold=0.001)
        bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.object.mode_set(mode='OBJECT')

    create_obj("Track_Base-col", verts, faces, face_mats, [m_asphalt, m_turf, m_barrier])
    create_obj("Track_Boosts", boost_verts, boost_faces, boost_face_mats, [m_boost])
    create_obj("Track_Checkpoints", check_verts, check_faces, check_face_mats, [m_check])

if __name__ == "__main__":
    build_track()
