import Foundation
import KM16ControlCore

extension Presets {
    public static func gitReview() -> Profile {
        let target = "com.microsoft.VSCode"
        return makeProfile(
            id: "BFE1910C-C69B-4A51-9E50-C6F7760D16C8",
            presetID: "git-review",
            name: "Git Review",
            summary: "Visual Studio Code source-control review, staging, history, and remote controls.",
            actions: [
                shortcut("Source Control", "ctrl+shift+g", "Open VS Code's Source Control view.", target),
                shortcut("Open all changes", "ctrl+alt+shift+1", "Open every working-tree change in VS Code's multi-diff editor; requires the supplied keybinding.", target),
                shortcut("View unstaged changes", "ctrl+alt+shift+2", "Open the current repository's unstaged changes; requires the supplied keybinding.", target),
                shortcut("View staged changes", "ctrl+alt+shift+3", "Open the current repository's staged changes; requires the supplied keybinding.", target),
                shortcut("View untracked changes", "ctrl+alt+shift+4", "Open the current repository's untracked files; requires the supplied keybinding.", target),
                shortcut("Git output", "ctrl+alt+shift+5", "Show the Git output channel for diagnostics; requires the supplied keybinding.", target),
                shortcut("Stage selected ranges", "ctrl+alt+shift+6", "Stage the selected ranges in an active Git diff editor; requires the supplied keybinding.", target),
                shortcut("Unstage selected ranges", "ctrl+alt+shift+7", "Unstage the selected ranges in an active Git diff editor; requires the supplied keybinding.", target),
                shortcut("Stage selected item", "ctrl+alt+shift+8", "Stage the selected Source Control resource; requires the supplied keybinding.", target),
                shortcut("Unstage selected item", "ctrl+alt+shift+9", "Unstage the selected Source Control resource; requires the supplied keybinding.", target),
                shortcut("Stage all", "ctrl+alt+shift+0", "Stage all changes in the chosen repository; requires the supplied keybinding.", target),
                shortcut("Unstage all", "ctrl+alt+shift+a", "Unstage all changes in the chosen repository; requires the supplied keybinding.", target),
                shortcut("Fetch", "ctrl+alt+shift+b", "Fetch remote refs for the chosen repository without merging; requires the supplied keybinding.", target),
                shortcut("Pull", "ctrl+alt+shift+c", "Pull the upstream branch for the chosen repository; requires the supplied keybinding.", target),
                shortcut("Push", "ctrl+alt+shift+d", "Push the current branch to its configured upstream; requires the supplied keybinding.", target),
                shortcut("View commit", "ctrl+alt+shift+e", "Choose a commit and open its changes in VS Code; requires the supplied keybinding.", target),
                shortcut("Previous change", "ctrl+alt+shift+f", "Move to the previous change in the active VS Code diff editor; requires the supplied keybinding.", target),
                shortcut("Next change", "ctrl+alt+shift+g", "Move to the next change in the active VS Code diff editor; requires the supplied keybinding.", target),
                shortcut("Open selected diff", "ctrl+alt+shift+h", "Open the selected Source Control resource as a diff; requires the supplied keybinding.", target),
                shortcut("Previous editor", "ctrl+shift+tab", "Select the previous open VS Code editor.", target),
                shortcut("Next editor", "ctrl+tab", "Select the next open VS Code editor.", target),
                shortcut("Focus Source Control", "ctrl+shift+g", "Focus VS Code's Source Control view.", target),
                system("Scroll review up", "scrollUp", "Scroll the active VS Code review surface upward.", target),
                system("Scroll review down", "scrollDown", "Scroll the active VS Code review surface downward.", target),
                shortcut("Open working file", "ctrl+alt+shift+i", "Open the working-tree version of the selected Source Control resource; requires the supplied keybinding.", target)
            ]
        )
    }

    public static func terminal() -> Profile {
        let target = "com.apple.Terminal"
        return makeProfile(
            id: "8E25FD73-31E9-4B2E-992E-23AB9F21F8B4",
            presetID: "terminal",
            name: "Terminal",
            summary: "Apple Terminal windows, tabs, panes, navigation, and inert command-line snippets.",
            matchingBundleIDs: [target],
            actions: [
                launch("Open Terminal", target, "Bring Apple Terminal to the foreground."),
                shortcut("New window", "cmd+n", "Open a new Terminal window with the default profile.", target),
                shortcut("New tab", "cmd+t", "Open a new tab in the active Terminal window.", target),
                shortcut("Split pane", "cmd+d", "Split the active Terminal tab into two panes.", target),
                shortcut("Close split pane", "shift+cmd+d", "Close the active split pane without closing the tab.", target),
                shortcut("Find", "cmd+f", "Open Terminal's text search bar.", target),
                shortcut("Clear to start", "cmd+k", "Clear Terminal output back to the start of the scrollback buffer.", target),
                shortcut("Reverse history search", "ctrl+r", "Start the shell's reverse command-history search.", target),
                insertSnippet("Git status", "git status --short --branch", "Insert a concise Git status command without sending Return.", target),
                insertSnippet("Git diff summary", "git diff --stat", "Insert a Git working-tree summary command without sending Return.", target),
                insertSnippet("Recent commits", "git log --oneline --decorate -20", "Insert a compact recent-history command without sending Return.", target),
                insertSnippet("Current directory", "pwd", "Insert the command that prints the current directory without sending Return.", target),
                insertSnippet("List files", "ls -la", "Insert a detailed directory listing command without sending Return.", target),
                insertSnippet("Disk usage", "du -sh .", "Insert a command that totals the current directory's disk usage without sending Return.", target),
                insertSnippet("Listening ports", "lsof -nP -iTCP -sTCP:LISTEN", "Insert a command that lists local listening TCP sockets without sending Return.", target),
                insertSnippet("Process snapshot", "ps -axo pid,ppid,%cpu,%mem,command", "Insert a portable process snapshot command without sending Return.", target),
                shortcut("Previous tab", "ctrl+shift+tab", "Select the previous Terminal tab.", target),
                shortcut("Next tab", "ctrl+tab", "Select the next Terminal tab.", target),
                shortcut("Show all tabs", "shift+cmd+\\", "Enter or leave Terminal's tab overview.", target),
                shortcut("Scroll one line up", "alt+cmd+pageup", "Scroll the active Terminal pane upward by one line.", target),
                shortcut("Scroll one line down", "alt+cmd+pagedown", "Scroll the active Terminal pane downward by one line.", target),
                shortcut("Scroll to bottom", "cmd+end", "Move the active Terminal pane to the bottom of its scrollback.", target),
                shortcut("Smaller text", "cmd+minus", "Decrease Terminal's displayed font size.", target),
                shortcut("Larger text", "cmd+plus", "Increase Terminal's displayed font size.", target),
                shortcut("Inspector", "cmd+i", "Show or hide the Terminal inspector for the active session.", target)
            ]
        )
    }

    public static func researchWriting() -> Profile {
        let cotEditor = "com.coteditor.CotEditor"
        let safari = "com.apple.Safari"
        let notes = "com.apple.Notes"
        return makeProfile(
            id: "0FE1C1A9-3D79-41C8-991F-D8C1DE4B2532",
            presetID: "research-writing",
            name: "Research & Writing",
            summary: "Markdown drafting in CotEditor with focused Safari reading and Apple Notes capture controls.",
            matchingBundleIDs: [cotEditor],
            actions: [
                launch("Open CotEditor", cotEditor, "Bring CotEditor to the foreground for Markdown drafting."),
                shortcut("New draft", "cmd+n", "Create a new plain-text document in CotEditor.", cotEditor),
                shortcut("Open document", "cmd+o", "Open a text or Markdown document in CotEditor.", cotEditor),
                shortcut("Save draft", "cmd+s", "Save the active CotEditor document.", cotEditor),
                shortcut("Save draft as", "shift+cmd+s", "Save the active CotEditor document under a new name.", cotEditor),
                shortcut("Find in draft", "cmd+f", "Open CotEditor's find interface for the active document.", cotEditor),
                shortcut("Find next", "cmd+g", "Select the next match in CotEditor.", cotEditor),
                shortcut("Find previous", "shift+cmd+g", "Select the previous match in CotEditor.", cotEditor),
                insertSnippet("Heading", "## Section", "Insert a level-two Markdown heading at the insertion point.", cotEditor),
                insertSnippet("Task item", "- [ ] Task", "Insert an unchecked Markdown task-list item at the insertion point.", cotEditor),
                insertSnippet("Link", "[title](https://example.com)", "Insert a Markdown link template ready for replacement.", cotEditor),
                insertSnippet("Code fence", "```text\ncode\n```", "Insert a fenced Markdown code-block template.", cotEditor),
                launch("Open Safari", safari, "Bring Safari to the foreground for source reading."),
                shortcut("Safari Reader", "shift+cmd+r", "Open Reader for the current Safari article when Reader is available.", safari),
                shortcut("Save to Reading List", "shift+cmd+d", "Add the current Safari page to Reading List.", safari),
                launch("Open Notes", notes, "Bring Apple Notes to the foreground for quick research capture."),
                shortcut("Smaller draft text", "cmd+minus", "Decrease the displayed text size in CotEditor.", cotEditor),
                shortcut("Larger draft text", "cmd+plus", "Increase the displayed text size in CotEditor.", cotEditor),
                shortcut("Show outline", "ctrl+cmd+o", "Show CotEditor's Outline inspector after assigning the documented custom binding.", cotEditor),
                shortcut("Previous Safari tab", "ctrl+shift+tab", "Select the previous tab in Safari.", safari),
                shortcut("Next Safari tab", "ctrl+tab", "Select the next tab in Safari.", safari),
                shortcut("Safari search field", "cmd+l", "Focus Safari's Smart Search field.", safari),
                shortcut("Previous linked note", "alt+cmd+[", "Return to the Apple Note that linked to the current note.", notes),
                shortcut("Next linked note", "alt+cmd+]", "Go forward to the linked Apple Note.", notes),
                shortcut("Search all notes", "alt+cmd+f", "Search across all Apple Notes accounts.", notes)
            ]
        )
    }

    public static func windowManagement() -> Profile {
        makeProfile(
            id: "C92A50E6-2AD8-4DD2-8F0D-5E75E86E3A67",
            presetID: "window-management",
            name: "Window Management",
            summary: "Native macOS window placement, display movement, app-window navigation, Spaces, and zoom controls.",
            actions: [
                system("Left half", "windowLeftHalf", "Move and resize the active window to the left half of its desktop."),
                system("Right half", "windowRightHalf", "Move and resize the active window to the right half of its desktop."),
                system("Top half", "windowTopHalf", "Move and resize the active window to the top half of its desktop."),
                system("Bottom half", "windowBottomHalf", "Move and resize the active window to the bottom half of its desktop."),
                system("Top-left quarter", "windowTopLeft", "Move and resize the active window to the top-left quarter of its desktop."),
                system("Top-right quarter", "windowTopRight", "Move and resize the active window to the top-right quarter of its desktop."),
                system("Bottom-left quarter", "windowBottomLeft", "Move and resize the active window to the bottom-left quarter of its desktop."),
                system("Bottom-right quarter", "windowBottomRight", "Move and resize the active window to the bottom-right quarter of its desktop."),
                system("Maximize", "windowMaximize", "Fill the current desktop with the active window while keeping it out of full-screen mode."),
                system("Center", "windowCenter", "Center the active window on its current desktop."),
                system("Restore size", "windowRestore", "Return the active window to its size before the last native tile or fill operation."),
                system("Previous display", "windowPreviousDisplay", "Move the active window to the previous connected display."),
                system("Next display", "windowNextDisplay", "Move the active window to the next connected display."),
                system("Minimize", "windowMinimize", "Minimize the active window into the Dock."),
                system("Previous app window", "windowPrevious", "Focus the previous standard window belonging to the active app."),
                system("Next app window", "windowNext", "Focus the next standard window belonging to the active app."),
                shortcut("Previous Space", "ctrl+left", "Move to the Space immediately to the left using the configured Mission Control shortcut."),
                shortcut("Next Space", "ctrl+right", "Move to the Space immediately to the right using the configured Mission Control shortcut."),
                shortcut("Mission Control", "ctrl+up", "Show Mission Control using the configured macOS shortcut."),
                shortcut("Previous window shortcut", "shift+cmd+backtick", "Ask the active app to select its previous window using the standard Window-menu shortcut."),
                shortcut("Next window shortcut", "cmd+backtick", "Ask the active app to select its next window using the standard Window-menu shortcut."),
                shortcut("Application Windows", "ctrl+down", "Show all windows for the active app using the configured Mission Control shortcut."),
                shortcut("Zoom out", "cmd+minus", "Ask the active app to decrease its document or content zoom when supported."),
                shortcut("Zoom in", "cmd+plus", "Ask the active app to increase its document or content zoom when supported."),
                shortcut("Toggle full screen", "ctrl+cmd+f", "Ask the active app to enter or leave full-screen mode.")
            ]
        )
    }

    public static func recordingStreaming() -> Profile {
        let target = "com.obsproject.obs-studio"
        return makeProfile(
            id: "4960743D-F082-41F5-BC8C-9291C0945238",
            presetID: "recording-streaming",
            name: "Recording & Streaming",
            summary: "OBS Studio scenes, recording, replay buffer, studio transition, and audio controls.",
            matchingBundleIDs: [target],
            actions: [
                launch("Open OBS Studio", target, "Bring OBS Studio to the foreground."),
                obs("Scene 1", "scene-1", "Make the first scene in the current OBS collection the Program scene."),
                obs("Scene 2", "scene-2", "Make the second scene in the current OBS collection the Program scene."),
                obs("Scene 3", "scene-3", "Make the third scene in the current OBS collection the Program scene."),
                obs("Scene 4", "scene-4", "Make the fourth scene in the current OBS collection the Program scene."),
                obs("Scene 5", "scene-5", "Make the fifth scene in the current OBS collection the Program scene."),
                obs("Scene 6", "scene-6", "Make the sixth scene in the current OBS collection the Program scene."),
                obs("Scene 7", "scene-7", "Make the seventh scene in the current OBS collection the Program scene."),
                obs("Scene 8", "scene-8", "Make the eighth scene in the current OBS collection the Program scene."),
                obs("Start recording", "start-recording", "Start OBS recording when no recording is active."),
                obs("Stop recording", "stop-recording", "Stop and finalize the active OBS recording."),
                obs("Pause recording", "pause-recording", "Pause the active OBS recording when the output supports pausing."),
                obs("Resume recording", "resume-recording", "Resume a paused OBS recording."),
                obs("Save replay", "save-replay", "Save the current OBS replay buffer when the buffer is running."),
                obs("Toggle Studio Mode", "toggle-studio-mode", "Enable or disable OBS Studio Mode."),
                obs("Transition", "transition", "Send the current preview scene to program while OBS Studio Mode is active."),
                obs("Microphone down", "mic-down", "Lower the configured OBS microphone input volume by one control step."),
                obs("Microphone up", "mic-up", "Raise the configured OBS microphone input volume by one control step."),
                obs("Mute microphone", "mic-mute", "Toggle muting for the configured OBS microphone input."),
                obs("Playback down", "playback-down", "Lower the configured OBS desktop or playback input volume by one control step."),
                obs("Playback up", "playback-up", "Raise the configured OBS desktop or playback input volume by one control step."),
                obs("Mute playback", "playback-mute", "Toggle muting for the configured OBS desktop or playback input."),
                obs("Previous scene", "previous-scene", "Make the scene immediately before the current scene the OBS Program scene."),
                obs("Next scene", "next-scene", "Make the scene immediately after the current scene the OBS Program scene."),
                profileSwitch("Window Management", "window-management", "Switch to the Window Management preset.")
            ]
        )
    }

    public static func videoEditing() -> Profile {
        let target = "com.apple.FinalCut"
        return makeProfile(
            id: "CC15B6E4-6DF0-4AE1-8201-BC2EA33151D7",
            presetID: "video-editing",
            name: "Video Editing",
            summary: "Final Cut Pro importing, timeline editing, tools, playback, navigation, and sharing using Apple defaults.",
            matchingBundleIDs: [target],
            actions: [
                launch("Open Final Cut Pro", target, "Bring Final Cut Pro to the foreground."),
                shortcut("Import media", "cmd+i", "Open Final Cut Pro's media import window.", target),
                shortcut("New project", "cmd+n", "Create a new Final Cut Pro project.", target),
                shortcut("Undo", "cmd+z", "Undo the last Final Cut Pro command.", target),
                shortcut("Redo", "shift+cmd+z", "Redo the last undone Final Cut Pro command.", target),
                shortcut("Append", "e", "Append the browser selection to the end of the primary storyline.", target),
                shortcut("Connect", "q", "Connect the browser selection to the primary storyline at the playhead.", target),
                shortcut("Insert", "w", "Insert the browser selection at the skimmer or playhead position.", target),
                shortcut("Overwrite", "d", "Overwrite the primary storyline at the skimmer or playhead with the browser selection.", target),
                shortcut("Blade", "cmd+b", "Cut the primary-storyline clip or current selection at the playhead.", target),
                shortcut("Blade all", "shift+cmd+b", "Cut every clip at the skimmer or playhead position.", target),
                shortcut("Delete selection", "delete", "Delete the timeline selection or reject the browser selection.", target),
                shortcut("Add marker", "m", "Add a marker at the skimmer or playhead position.", target),
                shortcut("Default title", "ctrl+t", "Connect the default title to the primary storyline.", target),
                shortcut("Transform tool", "shift+t", "Activate Transform and show its onscreen controls for the selected clip.", target),
                shortcut("Crop tool", "shift+c", "Activate Crop and show its onscreen controls for the selected clip.", target),
                shortcut("Play reverse", "j", "Play backward; repeat rotations to increase reverse playback speed.", target),
                shortcut("Play forward", "l", "Play forward; repeat rotations to increase forward playback speed.", target),
                shortcut("Stop playback", "k", "Stop Final Cut Pro playback.", target),
                shortcut("Previous frame", "left", "Move the playhead back by one frame.", target),
                shortcut("Next frame", "right", "Move the playhead forward by one frame.", target),
                shortcut("Play or pause", "space", "Start or pause playback at the playhead.", target),
                shortcut("Previous edit", "up", "Go to the previous item in the browser or edit point in the timeline.", target),
                shortcut("Next edit", "down", "Go to the next item in the browser or edit point in the timeline.", target),
                shortcut("Share default", "cmd+e", "Share the selected project or clip using the configured default destination.", target)
            ]
        )
    }

    public static func personalAutomations() -> Profile {
        let target = "com.apple.shortcuts"
        return makeProfile(
            id: "4F936DFC-B773-4FDB-84A0-256566F3612E",
            presetID: "personal-automations",
            name: "Personal Automations",
            summary: "User-owned Apple Shortcuts routines plus keyboard navigation for the Shortcuts app.",
            matchingBundleIDs: [target],
            actions: [
                runUserShortcut("Start Workday", "Run the user-created Start Workday routine."),
                runUserShortcut("End Workday", "Run the user-created End Workday routine."),
                runUserShortcut("Focus Session", "Run the user-created Focus Session routine."),
                runUserShortcut("Break Timer", "Run the user-created Break Timer routine."),
                runUserShortcut("Capture Idea", "Run the user-created Capture Idea routine."),
                runUserShortcut("New Journal Entry", "Run the user-created New Journal Entry routine."),
                runUserShortcut("Plan Today", "Run the user-created Plan Today routine."),
                runUserShortcut("Review Today", "Run the user-created Review Today routine."),
                runUserShortcut("Open Work Apps", "Run the user-created Open Work Apps routine."),
                runUserShortcut("Close Work Apps", "Run the user-created Close Work Apps routine."),
                runUserShortcut("Meeting Setup", "Run the user-created Meeting Setup routine."),
                runUserShortcut("Meeting Wrap-up", "Run the user-created Meeting Wrap-up routine."),
                runUserShortcut("Quiet Mode", "Run the user-created Quiet Mode routine."),
                runUserShortcut("Restore Notifications", "Run the user-created Restore Notifications routine."),
                runUserShortcut("Daily Backup", "Run the user-created Daily Backup routine."),
                runUserShortcut("Home Arrival", "Run the user-created Home Arrival routine."),
                shortcut("Previous shortcut", "up", "Move to the previous shortcut or row in the focused Shortcuts list.", target),
                shortcut("Next shortcut", "down", "Move to the next shortcut or row in the focused Shortcuts list.", target),
                shortcut("Open selected shortcut", "enter", "Open the selected shortcut or activate the focused Shortcuts control.", target),
                shortcut("Previous section", "shift+tab", "Move keyboard focus to the previous Shortcuts interface section.", target),
                shortcut("Next section", "tab", "Move keyboard focus to the next Shortcuts interface section.", target),
                shortcut("Activate control", "space", "Activate the focused Shortcuts button or toggle.", target),
                shortcut("Page up", "pageup", "Move upward by one page in the focused Shortcuts collection.", target),
                shortcut("Page down", "pagedown", "Move downward by one page in the focused Shortcuts collection.", target),
                shortcut("Search shortcuts", "cmd+f", "Focus search in the Shortcuts app.", target)
            ]
        )
    }

    private static func insertSnippet(_ label: String, _ text: String, _ detail: String, _ target: String) -> ControlAction {
        ControlAction(kind: .snippet, label: label, parameter: text, targetBundleID: target, detail: detail)
    }

    private static func obs(_ label: String, _ operation: String, _ detail: String) -> ControlAction {
        ControlAction(kind: .obsAction, label: label, parameter: operation, detail: detail)
    }

    private static func runUserShortcut(_ name: String, _ detail: String) -> ControlAction {
        let process = ProcessSpec(executable: "/usr/bin/shortcuts", args: ["run", name], timeoutSeconds: 300)
        return ControlAction(kind: .shell, label: name, parameter: process.encoded(), detail: "\(detail) This requires a user-owned shortcut with the exact name.")
    }
}
