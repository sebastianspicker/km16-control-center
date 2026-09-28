import Foundation
import KM16ControlCore

extension Presets {
    public static func modelling3D() -> Profile {
        let target = "org.blenderfoundation.blender"
        return makeProfile(
            id: "9F1C0DBD-AD2B-4F7B-A5AA-CECF82C0B8B0",
            presetID: "3d-modelling",
            name: "3D Modelling",
            summary: "Blender object and mesh modelling with transforms, selection, editing, viewport zoom, and animation controls.",
            matchingBundleIDs: [target],
            actions: [
                shortcut("Move", "g", "Move the selected object or mesh elements interactively.", target),
                shortcut("Rotate", "r", "Rotate the selected object or mesh elements interactively.", target),
                shortcut("Scale", "s", "Scale the selected object or mesh elements interactively.", target),
                shortcut("Toggle Edit Mode", "tab", "Switch the active object between Object Mode and Edit Mode.", target),
                shortcut("Extrude region", "e", "Extrude the selected mesh region interactively in Edit Mode.", target),
                shortcut("Inset faces", "i", "Inset the selected mesh faces interactively in Edit Mode.", target),
                shortcut("Bevel edges", "ctrl+b", "Bevel selected mesh edges interactively in Edit Mode.", target),
                shortcut("Loop cut", "ctrl+r", "Start Blender's interactive Loop Cut and Slide tool in Edit Mode.", target),
                shortcut("Select all", "a", "Select all compatible items in the Blender editor under the pointer.", target),
                shortcut("Deselect all", "alt+a", "Deselect all compatible items in the Blender editor under the pointer.", target),
                shortcut("Invert selection", "ctrl+i", "Invert the selection in the Blender editor under the pointer.", target),
                shortcut("Delete", "x", "Open Blender's context-sensitive delete confirmation for the current selection.", target),
                shortcut("Duplicate", "shift+d", "Duplicate the current object or mesh selection and enter interactive move.", target),
                shortcut("Add", "shift+a", "Open Blender's context-sensitive Add menu.", target),
                shortcut("Hide selected", "h", "Hide the selected objects or mesh elements.", target),
                shortcut("Reveal hidden", "alt+h", "Reveal hidden objects or mesh elements in the focused editor.", target),
                shortcut("Undo", "cmd+z", "Undo the most recent Blender operation using the macOS Command equivalent of Blender's Control shortcut.", target),
                shortcut("Redo", "shift+cmd+z", "Redo the most recently undone Blender operation using the macOS Command equivalent.", target),
                shortcut("Menu Search", "f3", "Open Blender's searchable command menu.", target),
                shortcut("Previous frame", "left", "Move the animation playhead to the previous frame when a compatible editor has focus.", target),
                shortcut("Next frame", "right", "Move the animation playhead to the next frame when a compatible editor has focus.", target),
                shortcut("Play or pause", "space", "Start or pause Blender animation playback.", target),
                system("Zoom out", "scrollDown", "Send a downward scroll step to zoom out when the pointer is over the 3D Viewport.", target),
                system("Zoom in", "scrollUp", "Send an upward scroll step to zoom in when the pointer is over the 3D Viewport.", target),
                shortcut("Frame all", "home", "Frame all objects in the 3D Viewport under the pointer.", target)
            ]
        )
    }

    public static func musicProduction() -> Profile {
        let target = "com.apple.logic10"
        return makeProfile(
            id: "C7B93C0A-F8D4-4ED8-92E1-A3266F817DA1",
            presetID: "music-production",
            name: "Music Production",
            summary: "Logic Pro recording, project editing, track creation, key views, navigation, and arrangement zoom controls.",
            matchingBundleIDs: [target],
            actions: [
                shortcut("Record", "r", "Start recording on record-enabled tracks at the playhead.", target),
                shortcut("Cycle Mode", "c", "Turn Logic Pro Cycle mode on or off.", target),
                shortcut("Metronome", "k", "Turn the Logic Pro metronome click on or off.", target),
                shortcut("Record enable", "ctrl+r", "Toggle record enable for the selected track.", target),
                shortcut("Undo", "cmd+z", "Undo the most recent Logic Pro edit.", target),
                shortcut("Redo", "shift+cmd+z", "Redo the most recently undone Logic Pro edit.", target),
                shortcut("Save", "cmd+s", "Save the current Logic Pro project.", target),
                shortcut("Bounce", "cmd+b", "Open Logic Pro's Bounce dialog for the current project or selection context.", target),
                shortcut("New audio track", "alt+cmd+a", "Create a new audio track in the Main Window.", target),
                shortcut("Instrument track", "alt+cmd+s", "Create a new software instrument track in the Main Window.", target),
                shortcut("Duplicate track", "cmd+d", "Create a new track with the selected track's settings.", target),
                shortcut("Delete track", "cmd+delete", "Delete the selected track from the Main Window.", target),
                shortcut("Mixer", "x", "Show or hide the Mixer.", target),
                shortcut("Automation", "a", "Show or hide track automation in the Main Window.", target),
                shortcut("Piano Roll", "p", "Show or hide the Piano Roll editor.", target),
                shortcut("Library", "y", "Show or hide the Library.", target),
                shortcut("Previous track", "up", "Select the previous track.", target),
                shortcut("Next track", "down", "Select the next track.", target),
                shortcut("Mute track", "m", "Toggle mute for the selected track's channel strip.", target),
                shortcut("Rewind", ",", "Move the Logic Pro playhead backward.", target),
                shortcut("Forward", ".", "Move the Logic Pro playhead forward.", target),
                shortcut("Play or stop", "space", "Start or stop playback at the current playhead position.", target),
                shortcut("Horizontal zoom out", "cmd+left", "Zoom the focused Logic Pro editor out horizontally.", target),
                shortcut("Horizontal zoom in", "cmd+right", "Zoom the focused Logic Pro editor in horizontally.", target),
                shortcut("Zoom selection or all", "z", "Toggle zoom to fit the selection or all contents in the focused editor.", target)
            ]
        )
    }
}
