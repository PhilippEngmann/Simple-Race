## Remove location transform from Kenney assets

import bpy
import os

# Set your paths
input_folder = "/home/pepe/Desktop/models/broken"
output_folder = "/home/pepe/Desktop/models/fixed"

# Get all .glb files
glb_files = [f for f in os.listdir(input_folder) if f.endswith('.glb')]

for glb_file in glb_files:
    # Clear scene
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()
    
    # Import
    filepath = os.path.join(input_folder, glb_file)
    bpy.ops.import_scene.gltf(filepath=filepath)
    
    # Fix all objects
    for obj in bpy.context.scene.objects:
        if obj.type == 'MESH':
            bpy.context.view_layer.objects.active = obj
            obj.select_set(True)
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
            
            bpy.ops.object.mode_set(mode='EDIT')
            bpy.ops.mesh.select_all(action='SELECT')
            bpy.ops.transform.translate(value=(0.35, -0.65, 0.01))  # Adjust as needed
            bpy.ops.object.mode_set(mode='OBJECT')
            
            bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
            obj.select_set(False)
    
    # Export
    output_path = os.path.join(output_folder, glb_file)
    bpy.ops.export_scene.gltf(filepath=output_path, export_format='GLB')
    
    print(f"Processed: {glb_file}")

print("Batch processing complete!")