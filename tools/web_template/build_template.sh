#!/bin/bash
# Builds a slimmer Godot 4.7.2 web export template (no 3D, unused modules off).
set -e
cd /tmp/claude-0/build
[ -d godot ] || git clone -q --depth 1 -b 4.7.2-stable https://github.com/godotengine/godot.git
[ -d emsdk ] || git clone -q --depth 1 https://github.com/emscripten-core/emsdk.git
cd emsdk && ./emsdk install 4.0.20 >/dev/null && ./emsdk activate 4.0.20 >/dev/null && source ./emsdk_env.sh >/dev/null && cd ..
python3 -m pip install -q scons
cat > godot/custom.py <<'PY'
disable_3d = "yes"
disable_navigation_2d = "no"
module_gltf_enabled = "no"
module_csg_enabled = "no"
module_gridmap_enabled = "no"
module_jolt_physics_enabled = "no"
module_godot_physics_3d_enabled = "no"
module_navigation_3d_enabled = "no"
module_openxr_enabled = "no"
module_mobile_vr_enabled = "no"
module_webxr_enabled = "no"
module_lightmapper_rd_enabled = "no"
module_xatlas_unwrap_enabled = "no"
module_meshoptimizer_enabled = "no"
module_raycast_enabled = "no"
module_theora_enabled = "no"
module_mp3_enabled = "no"
module_enet_enabled = "no"
module_upnp_enabled = "no"
module_webrtc_enabled = "no"
module_multiplayer_enabled = "no"
module_noise_enabled = "no"
module_camera_enabled = "no"
module_vhacd_enabled = "no"
module_basis_universal_enabled = "no"
module_astcenc_enabled = "no"
module_etcpak_enabled = "no"
module_ktx_enabled = "no"
module_tga_enabled = "no"
module_hdr_enabled = "no"
module_dds_enabled = "no"
module_bmp_enabled = "no"
module_occlusion_culling_enabled = "no"
module_interactive_music_enabled = "no"
PY
cd godot
scons platform=web target=template_release production=yes threads=no -j4 2>&1 | tail -20
ls -la bin/
