"""Start a dedicated, empty Blender modeling session without changing user preferences."""
import bpy
import addon_utils

addon_utils.enable("blender_mcp", default_set=False, persistent=False)
entry = bpy.context.preferences.addons.get("blender_mcp")
if entry is None:
    raise RuntimeError("The installed Blender MCP addon could not be enabled")
entry.preferences.telemetry_consent = False
scene = bpy.context.scene
scene.name = "BeatDrift_City_Workshop"
scene.blendermcp_port = 9876
scene.blendermcp_auto_start_server = True
for prop in ("blendermcp_use_polyhaven", "blendermcp_use_sketchfab", "blendermcp_use_polypizza",
             "blendermcp_use_hyper3d", "blendermcp_use_hunyuan3d", "blendermcp_use_meshy"):
    if hasattr(scene, prop):
        setattr(scene, prop, False)
print("BEATDRIFT_CITY_MCP_READY", bpy.app.version_string, flush=True)
