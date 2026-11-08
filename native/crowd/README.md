# Crowd numerical kernel

Windows x64 GDExtension for the numerical hot loop in `scripts/contact_swarm.gd`.
Route decisions and the 0.5s beat remain in GDScript. The native module performs
the same spatial pairs, interacting-region unions, half-plane projection and
swept-path conflict checks. It never accesses Nodes, enemy Dictionaries, audio,
weapon counts or renderer state. Unmodified clean matrix expansion retains its
existing fast path. The script solver remains available as a comparison/fallback
(`SWARM.use_native = false`).

The checked-in DLL is built with MSVC x64 `/O2 /fp:precise /MT`; it does not need
the separately installed MSVC runtime. Rebuild from the repository root:

```
python tools/build_crowd_kernel.py
```

Requires Visual Studio C++ x64 build tools and the Windows SDK, detected via
`vswhere`. Build intermediates go under ignored `work/crowd-build/`. Only the
Windows x64 binary is currently supplied. Other architectures retain GDScript.
Preserve the `.gdextension` and its DLL together when distributing the game.

`gdextension_interface.h` is the unchanged MIT-licensed official
[Godot 4.5 interface header](https://github.com/godotengine/godot/blob/4.5-stable/core/extension/gdextension_interface.h).
The adapter uses the stable C ABI as described by the
[official C extension guide](https://docs.godotengine.org/en/4.6/tutorials/scripting/gdextension/gdextension_c_example.html).
Its type sizes and `PackedFloat64Array.size` hash were checked against the local
Godot 4.7.2 `--dump-extension-api`: `float_64`, StringName8, String8,
PackedFloat64Array16, Variant24. No `godot-cpp` dependency.

Wire schema1: three header doubles (`1`, move count, maximum displacement), then
ten doubles per move: startXY, proposed endXY, hull clearance, movable,
deploying, deployment ID, pressure role, reserved. Output replaces endXY only;
input storage remains untouched via Godot copy-on-write. Invalid lengths,
non-finite numbers and counts outside0–4096 return unchanged input.

Verification: `tests/v28_crowd_kernel_review.gd`, `tests/v21_crowd_review.gd`,
`tests/v21_encirclement_review.gd`, `tests/v28_density_review.gd` and
`docs/V28_CROWD_PERFORMANCE.md`. Shortened `--profile-short` diagnostics are not
the final benchmark. Use `--force-script` to benchmark the script fallback.
