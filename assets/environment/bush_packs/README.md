# Bush packs used by Samotny Szlak

This directory contains only the curated, Godot-importable source models and textures
used by the procedural bush MultiMeshes. Original archives remain in Downloads.

- `real_bush`: broad leafy shrub used in forest margins and sheltered meadows.
- `bush_01`: smaller upright shrub used as a sparse meadow/forest transition variant.
- `cliff_shrub`: low rocky-slope shrub, restricted to elevated terrain.

The runtime renderer extracts mesh surfaces from the imported scenes and batches each
surface with `MultiMeshInstance3D`; source scenes are not instantiated per shrub.
