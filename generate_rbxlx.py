#!/usr/bin/env python3
"""
Generator for Anomaly228.rbxlx - Roblox Studio game file.
Creates a complete horror game set in a Russian apartment.
"""

import uuid
import os

ref_counter = 0

def new_ref():
    global ref_counter
    ref_counter += 1
    return f"RBX{ref_counter:08X}"

def escape_xml(text):
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")

def read_lua_file(filename):
    path = os.path.join(os.path.dirname(__file__), "src", filename)
    with open(path, "r") as f:
        return f.read()

def prop_string(name, value):
    return f'<string name="{name}">{escape_xml(value)}</string>'

def prop_bool(name, value):
    return f'<bool name="{name}">{"true" if value else "false"}</bool>'

def prop_int(name, value):
    return f'<int name="{name}">{value}</int>'

def prop_float(name, value):
    return f'<float name="{name}">{value}</float>'

def prop_double(name, value):
    return f'<double name="{name}">{value}</double>'

def prop_token(name, value):
    return f'<token name="{name}">{value}</token>'

def prop_vector3(name, x, y, z):
    return f'<Vector3 name="{name}"><X>{x}</X><Y>{y}</Y><Z>{z}</Z></Vector3>'

def prop_cframe(name, x, y, z, r00=1,r01=0,r02=0,r10=0,r11=1,r12=0,r20=0,r21=0,r22=1):
    return f'''<CoordinateFrame name="{name}">
        <X>{x}</X><Y>{y}</Y><Z>{z}</Z>
        <R00>{r00}</R00><R01>{r01}</R01><R02>{r02}</R02>
        <R10>{r10}</R10><R11>{r11}</R11><R12>{r12}</R12>
        <R20>{r20}</R20><R21>{r21}</R21><R22>{r22}</R22>
    </CoordinateFrame>'''

def prop_color3(name, r, g, b):
    return f'<Color3 name="{name}"><R>{r}</R><G>{g}</G><B>{b}</B></Color3>'

def prop_color3uint8(name, r, g, b):
    val = (r << 16) | (g << 8) | b
    return f'<Color3uint8 name="{name}">{val}</Color3uint8>'

def prop_brickcolor(name, value):
    return f'<int name="{name}">{value}</int>'

def prop_udim2(name, sx, ox, sy, oy):
    return f'<UDim2 name="{name}"><XS>{sx}</XS><XO>{ox}</XO><YS>{sy}</YS><YO>{oy}</YO></UDim2>'

def material_enum(material_name):
    materials = {
        "Plastic": 256, "Wood": 512, "Slate": 800, "Concrete": 816,
        "CorrodedMetal": 1040, "DiamondPlate": 1056, "Foil": 1072,
        "Grass": 1280, "Ice": 1536, "Marble": 784, "Granite": 832,
        "Brick": 848, "Pebble": 864, "Sand": 1296, "Fabric": 1312,
        "SmoothPlastic": 272, "Metal": 1088, "WoodPlanks": 528,
        "Cobblestone": 880, "Neon": 288, "Glass": 1568,
    }
    return materials.get(material_name, 256)

def part(name, size, position, color, material="SmoothPlastic", anchored=True, transparency=0, rotation=None, can_collide=True, children=""):
    ref = new_ref()
    sx, sy, sz = size
    px, py, pz = position
    r, g, b = [c/255.0 for c in color]
    mat = material_enum(material)
    
    cframe = prop_cframe("CFrame", px, py, pz)
    if rotation:
        import math
        rx, ry, rz = [math.radians(a) for a in rotation]
        cr, sr = math.cos(rx), math.sin(rx)
        cy, sy_r = math.cos(ry), math.sin(ry)
        cz, sz_r = math.cos(rz), math.sin(rz)
        r00 = cy*cz
        r01 = -cy*sz_r
        r02 = sy_r
        r10 = sr*sy_r*cz + cr*sz_r
        r11 = -sr*sy_r*sz_r + cr*cz
        r12 = -sr*cy
        r20 = -cr*sy_r*cz + sr*sz_r
        r21 = cr*sy_r*sz_r + sr*cz
        r22 = cr*cy
        cframe = prop_cframe("CFrame", px, py, pz, r00, r01, r02, r10, r11, r12, r20, r21, r22)

    return f'''
    <Item class="Part" referent="{ref}">
        <Properties>
            {prop_string("Name", name)}
            {prop_vector3("size", sx, sy, sz)}
            {cframe}
            {prop_color3("Color3", r, g, b)}
            {prop_token("Material", mat)}
            {prop_bool("Anchored", anchored)}
            {prop_float("Transparency", transparency)}
            {prop_bool("CanCollide", can_collide)}
            {prop_token("shape", 1)}
            {prop_float("TopSurface", 0)}
            {prop_float("BottomSurface", 0)}
        </Properties>
        {children}
    </Item>'''

def model(name, children):
    ref = new_ref()
    return f'''
    <Item class="Model" referent="{ref}">
        <Properties>
            {prop_string("Name", name)}
        </Properties>
        {children}
    </Item>'''

def folder(name, children):
    ref = new_ref()
    return f'''
    <Item class="Folder" referent="{ref}">
        <Properties>
            {prop_string("Name", name)}
        </Properties>
        {children}
    </Item>'''

def point_light(brightness=1, color=(255,255,200), range_val=20):
    ref = new_ref()
    r, g, b = [c/255.0 for c in color]
    return f'''
    <Item class="PointLight" referent="{ref}">
        <Properties>
            {prop_float("Brightness", brightness)}
            {prop_color3("Color", r, g, b)}
            {prop_float("Range", range_val)}
            {prop_bool("Enabled", True)}
        </Properties>
    </Item>'''

def spot_light(brightness=1, color=(255,255,200), range_val=20, angle=90):
    ref = new_ref()
    r, g, b = [c/255.0 for c in color]
    return f'''
    <Item class="SpotLight" referent="{ref}">
        <Properties>
            {prop_float("Brightness", brightness)}
            {prop_color3("Color", r, g, b)}
            {prop_float("Range", range_val)}
            {prop_float("Angle", angle)}
            {prop_bool("Enabled", True)}
            {prop_token("Face", 1)}
        </Properties>
    </Item>'''

def surface_gui(name, face=5, children=""):
    ref = new_ref()
    return f'''
    <Item class="SurfaceGui" referent="{ref}">
        <Properties>
            {prop_string("Name", name)}
            {prop_token("Face", face)}
            {prop_bool("Active", True)}
            {prop_udim2("CanvasSize", 0, 800, 0, 600)}
        </Properties>
        {children}
    </Item>'''

def image_label(name, size, position, image="", color=(255,255,255), bg_transparency=1):
    ref = new_ref()
    r, g, b = [c/255.0 for c in color]
    return f'''
    <Item class="ImageLabel" referent="{ref}">
        <Properties>
            {prop_string("Name", name)}
            {prop_udim2("Size", size[0], size[1], size[2], size[3])}
            {prop_udim2("Position", position[0], position[1], position[2], position[3])}
            {prop_string("Image", image)}
            {prop_color3("ImageColor3", r, g, b)}
            {prop_float("BackgroundTransparency", bg_transparency)}
            {prop_token("ScaleType", 1)}
        </Properties>
    </Item>'''

def frame(name, size, position, bg_color=(0,0,0), bg_transparency=0.8):
    ref = new_ref()
    r, g, b = [c/255.0 for c in bg_color]
    return f'''
    <Item class="Frame" referent="{ref}">
        <Properties>
            {prop_string("Name", name)}
            {prop_udim2("Size", size[0], size[1], size[2], size[3])}
            {prop_udim2("Position", position[0], position[1], position[2], position[3])}
            {prop_color3("BackgroundColor3", r, g, b)}
            {prop_float("BackgroundTransparency", bg_transparency)}
            {prop_int("BorderSizePixel", 0)}
        </Properties>
    </Item>'''

def text_label(name, text, size, position, text_color=(255,255,255), text_size=24, bg_transparency=1, font=4):
    ref = new_ref()
    r, g, b = [c/255.0 for c in text_color]
    return f'''
    <Item class="TextLabel" referent="{ref}">
        <Properties>
            {prop_string("Name", name)}
            {prop_string("Text", text)}
            {prop_udim2("Size", size[0], size[1], size[2], size[3])}
            {prop_udim2("Position", position[0], position[1], position[2], position[3])}
            {prop_color3("TextColor3", r, g, b)}
            {prop_int("TextSize", text_size)}
            {prop_token("Font", font)}
            {prop_float("BackgroundTransparency", bg_transparency)}
            {prop_bool("TextWrapped", True)}
        </Properties>
    </Item>'''

def script(name, source, class_name="Script"):
    ref = new_ref()
    return f'''
    <Item class="{class_name}" referent="{ref}">
        <Properties>
            {prop_string("Name", name)}
            <ProtectedString name="Source">{escape_xml(source)}</ProtectedString>
            {prop_bool("Disabled", False)}
        </Properties>
    </Item>'''

def remote_event(name):
    ref = new_ref()
    return f'''
    <Item class="RemoteEvent" referent="{ref}">
        <Properties>
            {prop_string("Name", name)}
        </Properties>
    </Item>'''

def spawn_location(position):
    ref = new_ref()
    px, py, pz = position
    return f'''
    <Item class="SpawnLocation" referent="{ref}">
        <Properties>
            {prop_string("Name", "SpawnLocation")}
            {prop_vector3("size", 4, 1, 4)}
            {prop_cframe("CFrame", px, py, pz)}
            {prop_color3("Color3", 0.39, 0.37, 0.33)}
            {prop_token("Material", material_enum("Concrete"))}
            {prop_bool("Anchored", True)}
            {prop_float("Transparency", 1)}
            {prop_bool("CanCollide", False)}
            {prop_float("TopSurface", 0)}
            {prop_float("BottomSurface", 0)}
            {prop_double("Duration", 0)}
            {prop_bool("Enabled", True)}
        </Properties>
    </Item>'''


def build_room():
    """Build the main room of the Russian apartment"""
    parts = []
    
    ROOM_W = 16
    ROOM_D = 14
    ROOM_H = 10
    WALL_T = 0.6
    
    WALL_COLOR = (205, 195, 170)
    FLOOR_COLOR = (139, 90, 43)
    CEILING_COLOR = (220, 215, 200)
    
    # Floor
    parts.append(part("Floor", (ROOM_W, WALL_T, ROOM_D), (0, 0, 0), FLOOR_COLOR, "WoodPlanks"))
    
    # Ceiling
    parts.append(part("Ceiling", (ROOM_W, WALL_T, ROOM_D), (0, ROOM_H, 0), CEILING_COLOR, "SmoothPlastic"))
    
    # Back wall (with window)
    parts.append(part("BackWallLeft", (5, ROOM_H, WALL_T), (-5.5, ROOM_H/2, -ROOM_D/2), WALL_COLOR, "Concrete"))
    parts.append(part("BackWallRight", (5, ROOM_H, WALL_T), (5.5, ROOM_H/2, -ROOM_D/2), WALL_COLOR, "Concrete"))
    parts.append(part("BackWallTop", (6, 2.5, WALL_T), (0, ROOM_H-1.25, -ROOM_D/2), WALL_COLOR, "Concrete"))
    parts.append(part("BackWallBottom", (6, 2, WALL_T), (0, 1, -ROOM_D/2), WALL_COLOR, "Concrete"))
    
    # Window glass
    parts.append(part("WindowGlass", (5.5, 5, 0.2), (0, 4.5, -ROOM_D/2+0.1), (180, 210, 230), "Glass", transparency=0.6))
    
    # Window frame
    parts.append(part("WindowFrameH1", (6, 0.3, 0.4), (0, 2, -ROOM_D/2), (200, 190, 170), "Wood"))
    parts.append(part("WindowFrameH2", (6, 0.3, 0.4), (0, 7.2, -ROOM_D/2), (200, 190, 170), "Wood"))
    parts.append(part("WindowFrameV1", (0.3, 5.5, 0.4), (-2.85, 4.5, -ROOM_D/2), (200, 190, 170), "Wood"))
    parts.append(part("WindowFrameV2", (0.3, 5.5, 0.4), (2.85, 4.5, -ROOM_D/2), (200, 190, 170), "Wood"))
    parts.append(part("WindowFrameCenter", (0.2, 5.5, 0.4), (0, 4.5, -ROOM_D/2), (200, 190, 170), "Wood"))
    
    # Left wall
    parts.append(part("LeftWall", (WALL_T, ROOM_H, ROOM_D), (-ROOM_W/2, ROOM_H/2, 0), WALL_COLOR, "Concrete"))
    
    # Right wall (with doorway to hallway)
    parts.append(part("RightWallBack", (WALL_T, ROOM_H, 5), (ROOM_W/2, ROOM_H/2, -4.5), WALL_COLOR, "Concrete"))
    parts.append(part("RightWallFront", (WALL_T, ROOM_H, 5), (ROOM_W/2, ROOM_H/2, 4.5), WALL_COLOR, "Concrete"))
    parts.append(part("RightWallTop", (WALL_T, 2, 4), (ROOM_W/2, ROOM_H-1, 0), WALL_COLOR, "Concrete"))
    
    # Front wall
    parts.append(part("FrontWall", (ROOM_W, ROOM_H, WALL_T), (0, ROOM_H/2, ROOM_D/2), WALL_COLOR, "Concrete"))
    
    # Ceiling light
    parts.append(part("CeilingLight", (1.5, 0.3, 1.5), (0, ROOM_H-0.5, -1),
                       (255, 250, 220), "Glass", transparency=0.3,
                       children=point_light(1.2, (255, 240, 200), 30)))
    
    # Curtains (fabric panels near window)
    parts.append(part("CurtainLeft", (0.2, 6, 1.5), (-2.5, 4.5, -ROOM_D/2+0.5), (160, 140, 100), "Fabric"))
    parts.append(part("CurtainRight", (0.2, 6, 1.5), (2.5, 4.5, -ROOM_D/2+0.5), (160, 140, 100), "Fabric"))
    
    return model("Room", "\n".join(parts))


def build_furniture():
    """Build furniture for the room"""
    parts = []
    
    # === DESK (computer desk near left wall) ===
    desk_x = -5
    desk_z = -4
    desk_y = 2.8
    
    # Desk top
    parts.append(part("DeskTop", (6, 0.3, 3), (desk_x, desk_y, desk_z), (160, 120, 70), "Wood"))
    # Desk legs
    for dx, dz in [(-2.7, -1.2), (2.7, -1.2), (-2.7, 1.2), (2.7, 1.2)]:
        parts.append(part("DeskLeg", (0.3, desk_y-0.15, 0.3), (desk_x+dx, desk_y/2, desk_z+dz), (140, 100, 55), "Wood"))
    # Desk drawer unit (right side)
    parts.append(part("DeskDrawer", (2, 2, 2.5), (desk_x+2, 1.3, desk_z), (150, 110, 60), "Wood"))
    
    # === CRT MONITOR ===
    monitor_parts = []
    # Monitor base
    monitor_parts.append(part("MonitorBase", (2, 0.3, 1.5), (desk_x-1, desk_y+0.35, desk_z), (190, 185, 170), "SmoothPlastic"))
    # Monitor stand
    monitor_parts.append(part("MonitorStand", (1.2, 0.6, 1), (desk_x-1, desk_y+0.7, desk_z), (190, 185, 170), "SmoothPlastic"))
    # Monitor body (CRT box)
    monitor_parts.append(part("MonitorBody", (4, 3.5, 3), (desk_x-1, desk_y+2.8, desk_z), (190, 185, 170), "SmoothPlastic"))
    # Screen (front face - this is where the SurfaceGui goes)
    screen_children = surface_gui("SurfaceGui", 5,
        image_label("FaceImage", (0.8, 0, 0.8, 0), (0.1, 0, 0.1, 0), "", (200, 200, 200)) +
        frame("StaticOverlay", (1, 0, 1, 0), (0, 0, 0, 0), (0, 0, 0), 0.85)
    )
    monitor_parts.append(part("Screen", (3.5, 2.8, 0.2), (desk_x-1, desk_y+2.8, desk_z-1.55), (20, 20, 25), "Neon",
                               transparency=0, children=screen_children))
    # Monitor brand label
    monitor_parts.append(part("MonitorLabel", (1.5, 0.2, 0.1), (desk_x-1, desk_y+1.2, desk_z-1.5), (180, 175, 160), "SmoothPlastic"))
    
    parts.append(model("Monitor", "\n".join(monitor_parts)))
    
    # === SYSTEM UNIT (tower PC) ===
    parts.append(part("SystemUnit", (1.5, 4, 2.5), (desk_x+2, desk_y+2, desk_z), (200, 195, 180), "SmoothPlastic"))
    # Power button
    parts.append(part("PowerButton", (0.3, 0.3, 0.1), (desk_x+2, desk_y+3.5, desk_z-1.3), (50, 50, 50), "SmoothPlastic"))
    
    # === KEYBOARD ===
    parts.append(part("Keyboard", (3, 0.15, 1.2), (desk_x-1, desk_y+0.25, desk_z+0.5), (210, 205, 190), "SmoothPlastic"))
    
    # === MOUSE ===
    parts.append(part("Mouse", (0.6, 0.2, 0.9), (desk_x+1.5, desk_y+0.25, desk_z+0.3), (200, 195, 180), "SmoothPlastic"))
    
    # === CD on desk ===
    parts.append(part("CD", (0.8, 0.05, 0.8), (desk_x+1, desk_y+0.2, desk_z-0.5), (200, 200, 210), "Glass", transparency=0.3))
    
    # === Glass cup ===
    parts.append(part("Glass", (0.5, 0.7, 0.5), (desk_x+1.5, desk_y+0.55, desk_z-0.8), (180, 160, 140), "Glass", transparency=0.4))
    
    # === BED/SOFA (against left wall) ===
    bed_x = -5
    bed_z = 4
    # Bed frame
    parts.append(part("BedFrame", (5, 1.5, 3), (bed_x, 0.75, bed_z), (120, 80, 40), "Wood"))
    # Mattress
    parts.append(part("Mattress", (4.5, 0.6, 2.5), (bed_x, 1.8, bed_z), (180, 160, 130), "Fabric"))
    # Pillow
    parts.append(part("Pillow", (1.5, 0.4, 1), (bed_x-1.2, 2.2, bed_z), (200, 190, 170), "Fabric"))
    # Blanket
    parts.append(part("Blanket", (4, 0.3, 2.2), (bed_x+0.3, 2.0, bed_z+0.2), (140, 100, 80), "Fabric"))
    
    # === BOOKSHELF / СТЕНКА (against front wall, right side) ===
    shelf_x = 4
    shelf_z = 5.5
    # Main body
    parts.append(part("ShelfBody", (5, 8, 1.5), (shelf_x, 4, shelf_z), (120, 75, 35), "Wood"))
    # Shelves
    for sy in [1.5, 3, 4.5, 6, 7.5]:
        parts.append(part(f"Shelf_{sy}", (4.5, 0.2, 1.3), (shelf_x, sy, shelf_z), (130, 85, 40), "Wood"))
    # Glass door on top section
    parts.append(part("ShelfGlass", (2, 2.5, 0.15), (shelf_x-0.5, 6.75, shelf_z-0.7), (200, 220, 230), "Glass", transparency=0.5))
    # Books on shelves
    book_colors = [(150, 30, 30), (30, 60, 120), (40, 100, 40), (120, 80, 30), (80, 30, 80)]
    for i, (bx, by) in enumerate([(3.2, 2), (3.7, 2), (4.2, 2), (4.7, 2), (3.5, 3.5), (4, 3.5), (4.5, 3.5)]):
        color = book_colors[i % len(book_colors)]
        parts.append(part(f"Book_{i}", (0.3, 1, 0.8), (bx, by, shelf_z), color, "SmoothPlastic"))
    
    # === CHAIR at desk ===
    chair_x = desk_x - 1
    chair_z = desk_z + 2.5
    parts.append(part("ChairSeat", (1.8, 0.3, 1.8), (chair_x, 1.8, chair_z), (60, 50, 40), "Fabric"))
    for dx, dz in [(-0.7, -0.7), (0.7, -0.7), (-0.7, 0.7), (0.7, 0.7)]:
        parts.append(part("ChairLeg", (0.2, 1.5, 0.2), (chair_x+dx, 0.9, chair_z+dz), (50, 50, 50), "Metal"))
    parts.append(part("ChairBack", (1.8, 2.5, 0.3), (chair_x, 3.2, chair_z+0.75), (60, 50, 40), "Fabric"))
    
    # === SOLUTION BOTTLE (on shelf, pickupable item) ===
    solution_parts = []
    solution_parts.append(part("SolutionBottle", (0.4, 0.8, 0.4), (shelf_x+1.5, 5, shelf_z), (50, 120, 50), "Glass", transparency=0.3,
                                children=point_light(0.3, (0, 255, 0), 3)))
    parts.append(model("Solution", "\n".join(solution_parts)))
    
    # === PICTURE ON WALL ===
    parts.append(part("PictureFrame", (2.5, 2, 0.2), (4, 6, 6.7), (60, 40, 25), "Wood"))
    parts.append(part("PictureCanvas", (2, 1.5, 0.1), (4, 6, 6.6), (30, 30, 30), "SmoothPlastic"))
    
    # === RADIATOR under window ===
    parts.append(part("Radiator", (3, 1.5, 0.4), (0, 1, -6.5), (220, 220, 220), "Metal"))
    
    return model("Furniture", "\n".join(parts))


def build_hallway():
    """Build the hallway connecting room to entrance door"""
    parts = []
    
    HALL_W = 4
    HALL_D = 10
    HALL_H = 10
    WALL_T = 0.6
    
    hall_x = 10  # Right of the room
    hall_z = 0
    
    WALL_COLOR = (195, 185, 160)
    FLOOR_COLOR = (160, 130, 90)
    
    # Floor
    parts.append(part("HallFloor", (HALL_W, WALL_T, HALL_D), (hall_x, 0, hall_z), FLOOR_COLOR, "WoodPlanks"))
    
    # Ceiling
    parts.append(part("HallCeiling", (HALL_W, WALL_T, HALL_D), (hall_x, HALL_H, hall_z), (220, 215, 200), "SmoothPlastic"))
    
    # Left wall (shared with room)
    # Already handled by room's right wall
    
    # Right wall
    parts.append(part("HallRightWall", (WALL_T, HALL_H, HALL_D), (hall_x+HALL_W/2, HALL_H/2, hall_z), WALL_COLOR, "Concrete"))
    
    # Back wall
    parts.append(part("HallBackWall", (HALL_W, HALL_H, WALL_T), (hall_x, HALL_H/2, -HALL_D/2), WALL_COLOR, "Concrete"))
    
    # Front wall (with door opening)
    parts.append(part("HallFrontWallLeft", (1, HALL_H, WALL_T), (hall_x-1.5, HALL_H/2, HALL_D/2), WALL_COLOR, "Concrete"))
    parts.append(part("HallFrontWallRight", (1, HALL_H, WALL_T), (hall_x+1.5, HALL_H/2, HALL_D/2), WALL_COLOR, "Concrete"))
    parts.append(part("HallFrontWallTop", (2, 2, WALL_T), (hall_x, HALL_H-1, HALL_D/2), WALL_COLOR, "Concrete"))
    
    # Hall light
    parts.append(part("HallLight", (1, 0.2, 1), (hall_x, HALL_H-0.5, hall_z),
                       (255, 240, 200), "Glass", transparency=0.3,
                       children=point_light(0.6, (255, 230, 180), 20)))
    
    # === ENTRANCE DOOR ===
    door_parts = []
    
    # Door frame
    door_parts.append(part("DoorFrameLeft", (0.3, 8, 0.6), (hall_x-1.2, 4, HALL_D/2), (100, 60, 30), "Wood"))
    door_parts.append(part("DoorFrameRight", (0.3, 8, 0.6), (hall_x+1.2, 4, HALL_D/2), (100, 60, 30), "Wood"))
    door_parts.append(part("DoorFrameTop", (2.7, 0.3, 0.6), (hall_x, 8, HALL_D/2), (100, 60, 30), "Wood"))
    
    # Door panel (metal door)
    door_parts.append(part("DoorPanel", (2.2, 7.5, 0.3), (hall_x, 3.85, HALL_D/2), (100, 50, 30), "Metal"))
    
    # Door handle
    door_parts.append(part("Handle", (0.15, 0.5, 0.4), (hall_x+0.7, 4.2, HALL_D/2-0.25), (80, 80, 80), "Metal"))
    
    # Peephole
    door_parts.append(part("Peephole", (0.15, 0.15, 0.15), (hall_x, 5.5, HALL_D/2-0.2), (60, 60, 60), "Metal"))
    
    # Lock
    door_parts.append(part("Lock", (0.3, 0.2, 0.15), (hall_x+0.8, 3.5, HALL_D/2-0.2), (70, 70, 70), "Metal"))
    
    # Hinge part (for door animation)
    door_parts.append(part("Hinge", (0.1, 0.1, 0.1), (hall_x-1.1, 4, HALL_D/2), (100, 50, 30), "Metal", transparency=1))
    
    parts.append(model("Door", "\n".join(door_parts)))
    
    # === CLOTH (on hallway floor, pickupable) ===
    cloth_parts = []
    cloth_parts.append(part("ClothPart", (0.8, 0.1, 0.6), (hall_x+0.5, 0.4, hall_z-2), (200, 180, 50), "Fabric",
                             children=point_light(0.2, (255, 255, 0), 2)))
    parts.append(model("Cloth", "\n".join(cloth_parts)))
    
    # === COAT HOOKS on wall ===
    parts.append(part("CoatHook1", (0.1, 0.3, 0.2), (hall_x+1.7, 5.5, hall_z-1), (70, 70, 70), "Metal"))
    parts.append(part("CoatHook2", (0.1, 0.3, 0.2), (hall_x+1.7, 5.5, hall_z), (70, 70, 70), "Metal"))
    
    # Shoe rack
    parts.append(part("ShoeRack", (2, 0.8, 1), (hall_x+0.5, 0.4, hall_z+3), (130, 85, 40), "Wood"))
    
    return model("Hallway", "\n".join(parts))


def build_stairwell():
    """Build the stairwell visible through the door (подъезд)"""
    parts = []
    
    stair_x = 10
    stair_z = 8  # Beyond the door
    
    WALL_COLOR = (150, 140, 120)
    STAIR_COLOR = (130, 125, 115)
    
    # Stairwell floor
    parts.append(part("StairFloor", (6, 0.3, 6), (stair_x, 0, stair_z), (100, 95, 85), "Concrete"))
    
    # Stairwell walls
    parts.append(part("StairWallLeft", (0.4, 12, 6), (stair_x-3, 6, stair_z), WALL_COLOR, "Concrete"))
    parts.append(part("StairWallRight", (0.4, 12, 6), (stair_x+3, 6, stair_z), WALL_COLOR, "Concrete"))
    parts.append(part("StairWallBack", (6, 12, 0.4), (stair_x, 6, stair_z+3), WALL_COLOR, "Concrete"))
    
    # Stairs going up
    for i in range(8):
        parts.append(part(f"Stair_{i}", (3, 0.4, 1.2),
                          (stair_x, 0.5 + i * 0.9, stair_z + 0.5 * i),
                          STAIR_COLOR, "Concrete"))
    
    # Railing
    parts.append(part("Railing", (0.15, 5, 0.15), (stair_x-1.2, 3, stair_z+1), (60, 55, 50), "Metal"))
    parts.append(part("RailingTop", (0.15, 0.15, 4), (stair_x-1.2, 5.5, stair_z+2), (60, 55, 50), "Metal"))
    
    # Stairwell light
    parts.append(part("StairLight", (0.6, 0.6, 0.6), (stair_x, 11.5, stair_z+1),
                       (255, 230, 180), "Glass", transparency=0.2,
                       children=point_light(0.8, (255, 220, 160), 25)))
    
    # Stairwell ceiling
    parts.append(part("StairCeiling", (6, 0.3, 6), (stair_x, 12, stair_z), (170, 165, 155), "Concrete"))
    
    # Pipe on wall
    parts.append(part("Pipe", (0.15, 10, 0.15), (stair_x+2.5, 5, stair_z+2.5), (80, 80, 80), "Metal"))
    
    return model("Stairwell", "\n".join(parts))


def build_lighting():
    """Build lighting and atmosphere settings"""
    ref1 = new_ref()
    ref2 = new_ref()
    ref3 = new_ref()
    ref4 = new_ref()
    ref5 = new_ref()
    
    return f'''
    <Item class="Lighting" referent="{ref1}">
        <Properties>
            {prop_string("Name", "Lighting")}
            {prop_color3("Ambient", 0.08, 0.06, 0.04)}
            {prop_color3("OutdoorAmbient", 0.05, 0.05, 0.05)}
            {prop_float("Brightness", 0.3)}
            {prop_string("ClockTime", "22")}
            {prop_float("GeographicLatitude", 55.75)}
            {prop_color3("ColorShift_Top", 0.1, 0.08, 0.06)}
            {prop_color3("ColorShift_Bottom", 0.05, 0.04, 0.03)}
            {prop_float("EnvironmentDiffuseScale", 0.3)}
            {prop_float("EnvironmentSpecularScale", 0.2)}
            {prop_string("TimeOfDay", "22:00:00")}
            {prop_color3("FogColor", 0.05, 0.04, 0.03)}
            {prop_float("FogEnd", 200)}
            {prop_float("FogStart", 50)}
        </Properties>
        <Item class="Atmosphere" referent="{ref2}">
            <Properties>
                {prop_string("Name", "Atmosphere")}
                {prop_float("Density", 0.3)}
                {prop_float("Offset", 0)}
                {prop_color3("Color", 0.15, 0.12, 0.1)}
                {prop_color3("Decay", 0.85, 0.8, 0.75)}
                {prop_float("Glare", 0)}
                {prop_float("Haze", 2)}
            </Properties>
        </Item>
        <Item class="ColorCorrectionEffect" referent="{ref3}">
            <Properties>
                {prop_string("Name", "ColorCorrection")}
                {prop_float("Brightness", -0.05)}
                {prop_float("Contrast", 0.15)}
                {prop_float("Saturation", -0.3)}
                {prop_color3("TintColor", 0.9, 0.85, 0.75)}
            </Properties>
        </Item>
        <Item class="BloomEffect" referent="{ref4}">
            <Properties>
                {prop_string("Name", "Bloom")}
                {prop_float("Intensity", 0.15)}
                {prop_float("Size", 24)}
                {prop_float("Threshold", 0.9)}
            </Properties>
        </Item>
        <Item class="BlurEffect" referent="{ref5}">
            <Properties>
                {prop_string("Name", "Blur")}
                {prop_int("Size", 1)}
            </Properties>
        </Item>
    </Item>'''


def build_sounds():
    """Build ambient sound objects"""
    parts = []
    
    ref1 = new_ref()
    parts.append(f'''
    <Item class="Sound" referent="{ref1}">
        <Properties>
            {prop_string("Name", "AmbientHum")}
            {prop_bool("Looped", True)}
            {prop_bool("Playing", True)}
            {prop_double("Volume", 0.3)}
            {prop_string("SoundId", "rbxassetid://9112854440")}
        </Properties>
    </Item>''')
    
    ref2 = new_ref()
    parts.append(f'''
    <Item class="Sound" referent="{ref2}">
        <Properties>
            {prop_string("Name", "Heartbeat")}
            {prop_bool("Looped", True)}
            {prop_bool("Playing", False)}
            {prop_double("Volume", 0.5)}
            {prop_string("SoundId", "rbxassetid://9112854440")}
        </Properties>
    </Item>''')
    
    ref3 = new_ref()
    parts.append(f'''
    <Item class="Sound" referent="{ref3}">
        <Properties>
            {prop_string("Name", "Jumpscare")}
            {prop_bool("Looped", False)}
            {prop_bool("Playing", False)}
            {prop_double("Volume", 1)}
            {prop_string("SoundId", "rbxassetid://9112854440")}
        </Properties>
    </Item>''')
    
    return "\n".join(parts)


def build_replicated_storage():
    """Build ReplicatedStorage with events"""
    ref = new_ref()
    events_ref = new_ref()
    
    return f'''
    <Item class="ReplicatedStorage" referent="{ref}">
        <Properties>
            {prop_string("Name", "ReplicatedStorage")}
        </Properties>
        <Item class="Folder" referent="{events_ref}">
            <Properties>
                {prop_string("Name", "Events")}
            </Properties>
            {remote_event("GameState")}
            {remote_event("Interact")}
            {remote_event("ShowRule")}
        </Item>
    </Item>'''


def build_server_script_service():
    """Build ServerScriptService with game scripts"""
    ref = new_ref()
    game_manager_src = read_lua_file("GameManager.lua")
    
    return f'''
    <Item class="ServerScriptService" referent="{ref}">
        <Properties>
            {prop_string("Name", "ServerScriptService")}
        </Properties>
        {script("GameManager", game_manager_src, "Script")}
    </Item>'''


def build_starter_player():
    """Build StarterPlayer with client scripts"""
    ref = new_ref()
    ref2 = new_ref()
    
    monitor_src = read_lua_file("MonitorController.lua")
    rules_src = read_lua_file("RulesDisplay.lua")
    door_src = read_lua_file("DoorController.lua")
    horror_src = read_lua_file("HorrorEffects.lua")
    interact_src = read_lua_file("InteractionSystem.lua")
    
    return f'''
    <Item class="StarterPlayer" referent="{ref}">
        <Properties>
            {prop_string("Name", "StarterPlayer")}
        </Properties>
        <Item class="StarterPlayerScripts" referent="{ref2}">
            <Properties>
                {prop_string("Name", "StarterPlayerScripts")}
            </Properties>
            {script("MonitorController", monitor_src, "LocalScript")}
            {script("RulesDisplay", rules_src, "LocalScript")}
            {script("DoorController", door_src, "LocalScript")}
            {script("HorrorEffects", horror_src, "LocalScript")}
            {script("InteractionSystem", interact_src, "LocalScript")}
        </Item>
    </Item>'''


def build_starter_gui():
    """Build StarterGui with main GUI"""
    ref = new_ref()
    ref2 = new_ref()
    
    return f'''
    <Item class="StarterGui" referent="{ref}">
        <Properties>
            {prop_string("Name", "StarterGui")}
        </Properties>
        <Item class="ScreenGui" referent="{ref2}">
            <Properties>
                {prop_string("Name", "MainGui")}
                {prop_bool("ResetOnSpawn", False)}
                {prop_bool("IgnoreGuiInset", True)}
            </Properties>
        </Item>
    </Item>'''


def build_workspace():
    """Build the complete workspace"""
    ref = new_ref()
    
    apartment_content = "\n".join([
        build_room(),
        build_furniture(),
        build_hallway(),
        build_stairwell(),
    ])
    
    return f'''
    <Item class="Workspace" referent="{ref}">
        <Properties>
            {prop_string("Name", "Workspace")}
        </Properties>
        {model("Apartment", apartment_content)}
        {spawn_location((-2, 1.5, 0))}
        <Item class="Camera" referent="{new_ref()}">
            <Properties>
                {prop_string("Name", "Camera")}
                {prop_cframe("CFrame", -5, 5, 0)}
            </Properties>
        </Item>
        {build_sounds()}
    </Item>'''


def build_sound_service():
    ref = new_ref()
    return f'''
    <Item class="SoundService" referent="{ref}">
        <Properties>
            {prop_string("Name", "SoundService")}
            {prop_bool("RespectFilteringEnabled", True)}
        </Properties>
    </Item>'''


def generate():
    """Generate the complete .rbxlx file"""
    content = f'''<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">
    <External>null</External>
    <External>nil</External>
    {build_workspace()}
    {build_lighting()}
    {build_replicated_storage()}
    {build_server_script_service()}
    {build_starter_player()}
    {build_starter_gui()}
    {build_sound_service()}
</roblox>'''
    
    output_path = os.path.join(os.path.dirname(__file__), "Anomaly228.rbxlx")
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(content)
    
    print(f"Generated: {output_path}")
    print(f"Total references: {ref_counter}")


if __name__ == "__main__":
    generate()
