import Foundation
import KM16ControlCore

extension Presets {
    public static func photoEditing() -> Profile {
        let target = "com.canva.affinity"
        return makeProfile(
            id: "62041710-E430-4DB9-BDBB-37CA0D7AF44C", presetID: "photo-editing", name: "Photo Editing",
            summary: "Affinity Pixel Studio retouching, selections, layers, brush size, hardness, and canvas zoom.",
            matchingBundleIDs: [target], actions: [
                shortcut("Undo", "cmd+z", "Undo the last image edit.", target),
                shortcut("Redo", "cmd+shift+z", "Redo the last undone image edit.", target),
                shortcut("Save", "cmd+s", "Save the working Affinity document.", target),
                shortcut("Export", "cmd+alt+shift+s", "Open the image export dialog; choose format and destination there.", target),
                shortcut("Crop", "c", "Select Crop in Pixel Studio; finish text or numeric entry first. Check the studio binding during setup.", target),
                shortcut("Move", "v", "Select the Move tool for the current layer.", target),
                shortcut("Selection brush", "w", "Select or cycle the selection tool group in Pixel Studio; verify its binding in Shortcuts settings.", target),
                shortcut("Freehand selection", "l", "Select Freehand Selection in Pixel Studio; verify its binding in Shortcuts settings.", target),
                shortcut("Deselect", "cmd+d", "Clear the active pixel selection.", target),
                shortcut("Invert selection", "cmd+shift+i", "Invert the current pixel selection.", target),
                shortcut("Duplicate layer", "cmd+j", "Duplicate the selected layer to keep the original available.", target),
                shortcut("New pixel layer", "cmd+shift+n", "Create a new pixel layer for non-destructive retouching.", target),
                shortcut("Copy merged", "cmd+shift+c", "Copy the merged appearance of the selected image area.", target),
                shortcut("Merge visible copy", "cmd+alt+shift+e", "Create a merged visible layer above the existing layers.", target),
                shortcut("Reset colours", "d", "Reset foreground and background colours for mask painting.", target),
                shortcut("Swap colours", "shift+x", "Swap foreground and background colours for painting or masking.", target),
                shortcut("Smaller brush", "[", "Decrease brush width while a compatible pixel brush is active. Verify bracket bindings on your keyboard layout.", target),
                shortcut("Larger brush", "]", "Increase brush width while a compatible pixel brush is active.", target),
                shortcut("Paint brush", "b", "Select Paint Brush in Pixel Studio; verify this studio's B binding during setup.", target),
                shortcut("Softer brush", "shift+[", "Decrease supported pixel-brush hardness by ten percentage points; requires the documented binding in the active studio.", target),
                shortcut("Harder brush", "shift+]", "Increase supported pixel-brush hardness by ten percentage points; requires the documented binding in the active studio.", target),
                shortcut("Eraser", "e", "Select or cycle the erase brush group in Pixel Studio; verify its binding during setup.", target),
                shortcut("Zoom out", "cmd+minus", "Zoom out from the image canvas.", target),
                shortcut("Zoom in", "cmd+plus", "Zoom into the image canvas.", target),
                shortcut("Fit image", "cmd+0", "Fit the complete image in the document view.", target)
            ])
    }

    public static func presentations() -> Profile {
        let target = "com.microsoft.Powerpoint"
        return makeProfile(
            id: "6252708A-203E-4657-B27E-4D1D3C787E6A", presetID: "presentations", name: "Presentations",
            summary: "PowerPoint slide preparation and delivery, with slide, focus, and editing-zoom dials.",
            matchingBundleIDs: [target], actions: [
                shortcut("Present from start", "cmd+shift+enter", "Start the slide show from its first slide.", target),
                shortcut("Present current slide", "cmd+enter", "Start the slide show from the selected slide.", target),
                shortcut("Presenter View", "alt+enter", "Start the presentation in Presenter View.", target),
                shortcut("End presentation", "esc", "End the active slide show or cancel the current editing operation.", target),
                shortcut("Black screen", "b", "During a slide show, toggle a black screen. In text editing this types B.", target),
                shortcut("White screen", "w", "During a slide show, toggle a white screen. In text editing this types W.", target),
                shortcut("Laser pointer", "cmd+l", "During a slide show, activate the laser pointer.", target),
                shortcut("Arrow pointer", "cmd+a", "During a slide show, restore the arrow pointer; in editing, this selects all.", target),
                shortcut("New slide", "cmd+shift+n", "In editing view, insert a new slide.", target),
                shortcut("Duplicate slide", "cmd+shift+d", "In editing view, duplicate the selected slide.", target),
                shortcut("Undo", "cmd+z", "Undo the last presentation edit.", target),
                shortcut("Redo", "cmd+y", "Redo the last undone presentation edit.", target),
                shortcut("Save", "cmd+s", "Save the current presentation.", target),
                shortcut("Add comment", "cmd+shift+m", "In editing view, insert a comment on the selection.", target),
                shortcut("Insert hyperlink", "cmd+k", "In editing view, add a hyperlink to the selected object or text.", target),
                shortcut("Format background", "cmd+shift+2", "In editing view, open slide background formatting.", target),
                shortcut("Previous slide / step", "pageup", "Go to the previous slide in editing, or previous animation step during a slide show.", target),
                shortcut("Next slide / step", "pagedown", "Go to the next slide in editing, or next animation step during a slide show.", target),
                shortcut("Next animation", "space", "During a slide show, advance one animation or slide. In editing, Space may enter text or activate a focused control.", target),
                shortcut("Previous object / link", "shift+tab", "Move to the previous object in editing or hyperlink/control during presentation; context determines focus.", target),
                shortcut("Next object / link", "tab", "Move to the next object or presentation hotspot; inside text, inserts a tab.", target),
                shortcut("Activate link / control", "enter", "During a slide show, open the selected hyperlink. In editing, Return may enter text.", target),
                shortcut("Editing zoom out", "cmd+minus", "Decrease slide-canvas zoom in editing view.", target),
                shortcut("Editing zoom in", "cmd+plus", "Increase slide-canvas zoom in editing view.", target),
                shortcut("Fit slide", "cmd+alt+o", "Fit the slide to the editing window.", target)
            ])
    }
}
