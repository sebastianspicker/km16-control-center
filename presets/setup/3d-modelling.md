# 3D Modelling: Blender

This preset targets Blender (`org.blenderfoundation.blender`) and uses its standard Blender keymap. Before using it:

1. Open Blender Preferences with `Command-Comma`, choose Keymap, and select Blender rather than Industry Compatible. No custom entries or numpad shortcuts are required.
2. Grant KM16 Control Center access in System Settings > Privacy & Security > Accessibility.
3. Open a disposable `.blend` file and test the modelling controls before regular work. Delete still opens Blender's confirmation. Move, Rotate, Scale, Duplicate, Extrude, Inset, Bevel, and Loop Cut remain interactive in Blender.

Blender routes many shortcuts to the editor under the pointer. Keep it over the 3D Viewport for modelling, zoom, and Frame all. Keep it over a compatible animation editor for the previous-frame and next-frame controls. The main dial zooms only when the surface under the pointer treats scrolling as zoom.

The controls are arranged as follows:

| Controls | Assignment |
| --- | --- |
| Key row 1 | Move, Rotate, Scale, Toggle Edit Mode |
| Key row 2 | Extrude region, Inset faces, Bevel edges, Loop cut |
| Key row 3 | Select all, Deselect all, Invert selection, Delete |
| Key row 4 | Duplicate, Add, Hide selected, Reveal hidden |
| Upper-left encoder | Undo / Redo / Menu Search |
| Upper-right encoder | Previous frame / Next frame / Play or pause |
| Main encoder | Zoom out / Zoom in / Frame all |

The preset uses Blender's macOS Command forms for Undo and Redo. A custom keymap, keyboard layout, mode, selection, or pointer location can change the result of a control.

References:

- [Blender default keymap](https://docs.blender.org/manual/en/latest/interface/keymap/blender_default.html)
- [Blender transform basics](https://docs.blender.org/manual/en/latest/scene_layout/object/editing/transform/introduction.html)
- [Blender Extrude Region](https://docs.blender.org/manual/en/latest/modeling/meshes/tools/extrude_region.html)
- [Blender Loop Cut](https://docs.blender.org/manual/en/latest/modeling/meshes/tools/loop.html)
- [Blender 3D Viewport navigation](https://docs.blender.org/manual/en/latest/editors/3dview/navigate/navigation.html)
- [Blender macOS bundle declaration](https://github.com/blender/blender/blob/main/release/darwin/Blender.app/Contents/Info.plist)
