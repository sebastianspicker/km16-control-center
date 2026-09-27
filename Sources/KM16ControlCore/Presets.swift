import Foundation

public enum Presets {
    public static var all: [Profile] {
        ProfileOrganization.ordered([desktop(), agentDeck(), developer(), meetings(), creative(), gitReview(), terminal(), researchWriting(), windowManagement(), recordingStreaming(), videoEditing(), personalAutomations(), photoEditing(), modelling3D(), musicProduction(), presentations()])
    }

    public static func desktop() -> Profile {
        makeProfile(
            id: "3B2B8B5D-9387-4D04-9A21-1A1DA8027041",
            presetID: "desktop",
            name: "Desktop",
            summary: "Everyday macOS editing, app launching, media, volume, and scrolling controls.",
            actions: [
                shortcut("Copy", "cmd+c", "Copy the current selection."),
                shortcut("Paste", "cmd+v", "Paste clipboard contents."),
                shortcut("Cut", "cmd+x", "Cut the current selection."),
                shortcut("Undo", "cmd+z", "Undo the most recent edit."),
                shortcut("Redo", "cmd+shift+z", "Redo the most recently undone edit."),
                shortcut("Select all", "cmd+a", "Select the current document or list."),
                shortcut("New window", "cmd+n", "Open a new window in the foreground app."),
                shortcut("Save", "cmd+s", "Save the current document."),
                shortcut("Close window", "cmd+w", "Close the foreground window."),
                launch("Open Finder", "com.apple.finder", "Bring Finder to the foreground."),
                launch("Open Notes", "com.apple.Notes", "Bring Notes to the foreground."),
                launch("Open Safari", "com.apple.Safari", "Bring Safari to the foreground."),
                shortcut("Spotlight", "cmd+space", "Open Spotlight search."),
                shortcut("Capture region", "cmd+shift+4", "Start the macOS region screenshot tool."),
                shortcut("Lock screen", "ctrl+cmd+q", "Lock the current macOS session."),
                shortcut("Emoji & symbols", "ctrl+cmd+space", "Open the character viewer."),
                system("Volume down", "volumeDown", "Lower the default output volume."),
                system("Volume up", "volumeUp", "Raise the default output volume."),
                system("Mute", "mute", "Toggle default output muting."),
                system("Previous track", "previousTrack", "Ask the active media session for the previous item."),
                system("Next track", "nextTrack", "Ask the active media session for the next item."),
                system("Play or pause", "playPause", "Toggle the active media session."),
                system("Scroll up", "scrollUp", "Scroll the foreground view upward."),
                system("Scroll down", "scrollDown", "Scroll the foreground view downward."),
                profileSwitch("Agent Deck", "agent-deck", "Switch to the Agent Deck preset.")
            ]
        )
    }

    public static func agentDeck() -> Profile {
        makeProfile(
            id: "A0A9D0E6-00A7-4B50-B4DB-2C7D1007C5A4",
            presetID: "agent-deck",
            name: "Agent Deck",
            summary: "Codex task, review, test, navigation, and reusable prompt controls.",
            actions: [
                agent("New task", "new-task", "Start a new task in the current agent workspace."),
                agent("Review changes", "review-changes", "Ask the agent to review the current changes."),
                agent("Run tests", "run-tests", "Ask the agent to run the relevant test suite."),
                agent("Explain selection", "explain-selection", "Explain the selected code or text."),
                agent("Stop task", "stop-current-task", "Stop the current agent task."),
                agent("Summarize context", "summarize-context", "Summarize the current working context."),
                agent("Draft commit", "draft-commit", "Draft a commit message from the current changes."),
                prompt("Find regressions", "Review the current changes for concrete regressions.", "Run a focused regression review."),
                prompt("Explain failure", "Explain the latest failure and identify its root cause.", "Analyze the latest visible failure."),
                prompt("Plan next step", "Propose the smallest useful next implementation step.", "Plan a bounded follow-up change."),
                prompt("Check edge cases", "Check this implementation for missing edge cases.", "Review the current implementation's edge cases."),
                prompt("Improve names", "Suggest clearer names without changing behavior.", "Review identifiers for clarity."),
                prompt("Summarize diff", "Summarize the current diff for a reviewer.", "Prepare a concise reviewer-facing summary."),
                prompt("Check docs", "Check whether the documentation matches the implementation.", "Compare nearby documentation with current behavior."),
                prompt("Write handoff", "Draft a concise implementation handoff with checks and risks.", "Prepare a task handoff."),
                prompt("Ask one question", "Identify the single question that most affects correctness.", "Surface the most consequential open question."),
                agent("Previous task", "previous-task", "Select the previous task."),
                agent("Next task", "next-task", "Select the next task."),
                agent("Open task", "open-task", "Open the selected task."),
                agent("Previous changed file", "previous-changed-file", "Select the previous changed file."),
                agent("Next changed file", "next-changed-file", "Select the next changed file."),
                agent("Open diff", "open-diff", "Open the diff for the selected changed file."),
                agent("Scroll up", "scroll-up", "Scroll the agent view upward."),
                agent("Scroll down", "scroll-down", "Scroll the agent view downward."),
                profileSwitch("Desktop", "desktop", "Switch to the Desktop preset.")
            ]
        )
    }

    public static func developer() -> Profile {
        let target = "com.microsoft.VSCode"
        return makeProfile(
            id: "D341C844-69D3-49C2-92E8-A7F6014B6831",
            presetID: "developer",
            name: "Developer",
            summary: "Visual Studio Code navigation, editing, search, formatting, and task controls.",
            matchingBundleIDs: [target],
            actions: [
                shortcut("Command palette", "cmd+shift+p", "Show the VS Code Command Palette.", target),
                shortcut("Quick open", "cmd+p", "Open a file by name in VS Code.", target),
                shortcut("New file", "cmd+n", "Create a new untitled file in VS Code.", target),
                shortcut("Open file", "cmd+o", "Open a file in VS Code.", target),
                shortcut("Save", "cmd+s", "Save the active file in VS Code.", target),
                shortcut("Save all", "alt+cmd+s", "Save all edited files in VS Code.", target),
                shortcut("Close editor", "cmd+w", "Close the active VS Code editor.", target),
                shortcut("Reopen editor", "cmd+shift+t", "Reopen the most recently closed editor.", target),
                shortcut("Find", "cmd+f", "Find text in the active editor.", target),
                shortcut("Find in files", "cmd+shift+f", "Search across the current workspace.", target),
                shortcut("Replace", "alt+cmd+f", "Replace text in the active editor.", target),
                shortcut("Toggle comment", "cmd+/", "Toggle a line comment for the selection.", target),
                shortcut("Format document", "shift+alt+f", "Format the active document.", target),
                shortcut("Quick fix", "cmd+.", "Show available code actions and quick fixes.", target),
                shortcut("Go to definition", "f12", "Open the selected symbol's definition.", target),
                shortcut("Go to references", "shift+f12", "Show references for the selected symbol.", target),
                shortcut("Move line up", "alt+up", "Move the current line upward.", target),
                shortcut("Move line down", "alt+down", "Move the current line downward.", target),
                shortcut("Copy line down", "shift+alt+down", "Copy the current line below.", target),
                shortcut("Previous editor", "ctrl+shift+tab", "Select the previous open editor.", target),
                shortcut("Next editor", "ctrl+tab", "Select the next open editor.", target),
                shortcut("Toggle terminal", "ctrl+backtick", "Show or hide the integrated terminal.", target),
                system("Scroll editor up", "scrollUp", "Scroll the VS Code editor upward.", target),
                system("Scroll editor down", "scrollDown", "Scroll the VS Code editor downward.", target),
                shortcut("Run build task", "cmd+shift+b", "Run the configured default build task.", target)
            ]
        )
    }

    public static func meetings() -> Profile {
        let target = "us.zoom.xos"
        return makeProfile(
            id: "9BDF23B2-529C-4419-86E5-70BCE13D017B",
            presetID: "meetings",
            name: "Meetings",
            summary: "Zoom Workplace meeting, sharing, recording, participant, chat, and navigation controls.",
            matchingBundleIDs: [target],
            actions: [
                shortcut("Join meeting", "cmd+j", "Open Zoom's Join Meeting flow.", target),
                shortcut("Start meeting", "cmd+ctrl+v", "Start a Zoom meeting.", target),
                shortcut("Schedule meeting", "cmd+d", "Open Zoom's Schedule Meeting flow.", target),
                shortcut("Direct share", "cmd+ctrl+s", "Open Zoom's direct screen sharing flow.", target),
                shortcut("Mute or unmute", "cmd+shift+a", "Toggle your Zoom microphone.", target),
                shortcut("Start or stop video", "cmd+shift+v", "Toggle your Zoom camera.", target),
                shortcut("Switch camera", "cmd+shift+n", "Select the next available Zoom camera.", target),
                shortcut("Share screen", "cmd+shift+s", "Start or stop Zoom screen sharing.", target),
                shortcut("Pause sharing", "cmd+shift+t", "Pause or resume Zoom screen sharing.", target),
                shortcut("Local recording", "cmd+shift+r", "Start or stop a local Zoom recording.", target),
                shortcut("Cloud recording", "cmd+shift+c", "Start or stop a Zoom cloud recording when available.", target),
                shortcut("Change view", "cmd+shift+w", "Cycle Zoom speaker and gallery views.", target),
                shortcut("Participants", "cmd+u", "Show or hide Zoom's participants panel.", target),
                shortcut("Meeting chat", "cmd+shift+h", "Show or hide the in-meeting chat panel.", target),
                shortcut("Invite", "cmd+i", "Open the Zoom meeting invitation window.", target),
                shortcut("Copy invite link", "cmd+shift+i", "Copy the current Zoom meeting invitation link.", target),
                shortcut("Previous gallery page", "ctrl+p", "Show the previous gallery page.", target),
                shortcut("Next gallery page", "ctrl+n", "Show the next gallery page.", target),
                shortcut("Reactions", "cmd+shift+y", "Open the Zoom meeting reactions panel.", target),
                shortcut("Read active speaker", "cmd+2", "Ask Zoom to read the active speaker name.", target),
                shortcut("Full screen", "cmd+shift+f", "Enter or exit Zoom full screen mode.", target),
                shortcut("Minimal window", "cmd+shift+m", "Switch Zoom to its minimal meeting window.", target),
                shortcut("Raise or lower hand", "alt+y", "Toggle your raised-hand state in Zoom.", target),
                shortcut("Back in chat", "cmd+[", "Move backward in Zoom chat history.", target),
                shortcut("Global search", "cmd+e", "Open Zoom Workplace global search.", target)
            ]
        )
    }

    public static func creative() -> Profile {
        let target = "com.apple.Preview"
        return makeProfile(
            id: "C8E159A6-C837-4EB7-A8F1-D09D4ED94DE2",
            presetID: "creative",
            name: "Creative",
            summary: "Apple Preview document, image, page, zoom, and navigation controls.",
            matchingBundleIDs: [target],
            actions: [
                launch("Open Preview", target, "Bring Apple Preview to the foreground."),
                shortcut("Save", "cmd+s", "Save the current Preview document.", target),
                shortcut("Print", "cmd+p", "Print the current PDF or image.", target),
                shortcut("Copy selection", "cmd+c", "Copy selected text or image area.", target),
                shortcut("Cut selection", "cmd+x", "Cut the selected Preview item.", target),
                shortcut("Paste into image", "cmd+v", "Paste clipboard contents into an image.", target),
                shortcut("Next tab", "ctrl+tab", "Move to the next Preview tab.", target),
                shortcut("Previous tab", "shift+ctrl+tab", "Move to the previous Preview tab.", target),
                shortcut("Full screen", "ctrl+cmd+f", "Enter or leave Preview full screen mode.", target),
                shortcut("Previous page", "alt+up", "Move to the previous PDF page.", target),
                shortcut("Next page", "alt+down", "Move to the next PDF page.", target),
                shortcut("Actual size", "alt+cmd+0", "Show images at actual size.", target),
                shortcut("Zoom to fit", "alt+cmd+9", "Fit images to the Preview window.", target),
                shortcut("Zoom in", "alt+cmd+plus", "Zoom into all open images.", target),
                shortcut("Zoom out", "alt+cmd+minus", "Zoom out of all open images.", target),
                shortcut("Remove background", "shift+cmd+k", "Run Preview's Remove Background command.", target),
                shortcut("Scroll up a line", "up", "Scroll upward or select the previous sidebar item.", target),
                shortcut("Scroll down a line", "down", "Scroll downward or select the next sidebar item.", target),
                shortcut("Previous screen", "pageup", "Move up one screen or show the previous image.", target),
                shortcut("Next screen", "pagedown", "Move down one screen or show the next image.", target),
                shortcut("Previous document", "alt+pageup", "Move to the previous document in the window.", target),
                shortcut("Next document", "alt+pagedown", "Move to the next document in the window.", target),
                system("Smooth scroll up", "scrollUp", "Scroll the foreground Preview document upward.", target),
                system("Smooth scroll down", "scrollDown", "Scroll the foreground Preview document downward.", target),
                profileSwitch("Desktop", "desktop", "Switch to the Desktop preset.")
            ]
        )
    }

    public static func preset(id: String) -> Profile? {
        let normalized = id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return all.first { profile in
            profile.presetID?.lowercased() == normalized || profile.id.uuidString.lowercased() == normalized
        }
    }

    public static func factoryDocument() -> ProfileDocument {
        let profiles = all
        return ProfileDocument(activeProfileID: profiles[0].id, profiles: profiles)
    }

    static func makeProfile(
        id: String,
        presetID: String,
        name: String,
        summary: String,
        matchingBundleIDs: [String] = [],
        actions: [ControlAction]
    ) -> Profile {
        precondition(actions.count == ControlID.all.count, "Factory presets must assign every known control.")
        return Profile(
            id: UUID(uuidString: id)!,
            name: name,
            bindings: zip(ControlID.all, actions).map(Binding.init),
            summary: summary,
            matchingBundleIDs: matchingBundleIDs,
            presetID: presetID
        )
    }

    static func shortcut(_ label: String, _ parameter: String, _ detail: String, _ target: String? = nil) -> ControlAction {
        ControlAction(kind: .shortcut, label: label, parameter: parameter, targetBundleID: target, detail: detail)
    }

    static func launch(_ label: String, _ bundleID: String, _ detail: String) -> ControlAction {
        ControlAction(kind: .launchApp, label: label, parameter: bundleID, detail: detail)
    }

    static func system(_ label: String, _ parameter: String, _ detail: String, _ target: String? = nil) -> ControlAction {
        ControlAction(kind: .system, label: label, parameter: parameter, targetBundleID: target, detail: detail)
    }

    static func agent(_ label: String, _ parameter: String, _ detail: String) -> ControlAction {
        ControlAction(kind: .agentAction, label: label, parameter: parameter, detail: detail)
    }

    static func prompt(_ label: String, _ text: String, _ detail: String) -> ControlAction {
        ControlAction(kind: .agentAction, label: label, parameter: "prompt:\(text)", detail: detail)
    }

    static func profileSwitch(_ label: String, _ presetID: String, _ detail: String) -> ControlAction {
        ControlAction(kind: .profileSwitch, label: label, parameter: presetID, detail: detail)
    }
}
