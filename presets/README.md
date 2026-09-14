# KM16 preset library

The factory library contains 16 software profiles and 400 assignments. Each profile maps 16 keys and the clockwise, counterclockwise, and press inputs of three knobs. All assignments run on the Mac; they do not read or write KM16 firmware layers.

Open Preset Library in KM16 Control Center to browse profiles, read their setup guides, and add missing presets without replacing edited versions. Changes support Undo and remain unsaved until you select Save. You can also import `all.json` or an individual profile file. A profile-switch destination must already exist in the same library.

App-specific profiles require the named app and its default or documented custom shortcuts. The [setup guides](setup/) cover permissions, required bindings, and controls whose behavior depends on the active app or view. Export Setup Files… copies the guides and an additive VS Code keybindings fragment to a new folder; it does not change editor settings. Personal Automations calls your Apple Shortcuts by exact name, so create and review them first.

Imported profiles may insert text, run any absolute executable as your macOS user,
or send a custom prompt to the selected Codex thread. Importing does not run an
action or change the live-action setting. Inspect unfamiliar assignments before
running them.

Profiles use the same groups in the sidebar, preset library, and software profile cycle. Custom profiles have their own section and sort naturally by name. Renamed preset copies stay beside their source preset.

## Everyday

### Desktop

Everyday macOS editing, app launching, media, volume, and scrolling controls.

| Position | Left | Second | Third | Right |
| --- | --- | --- | --- | --- |
| Row 1 | Copy | Paste | Cut | Undo |
| Row 2 | Redo | Select all | New window | Save |
| Row 3 | Close window | Open Finder | Open Notes | Open Safari |
| Row 4 | Spotlight | Capture region | Lock screen | Emoji & symbols |

| Knob | Counterclockwise | Clockwise | Press |
| --- | --- | --- | --- |
| Upper-left | Volume down | Volume up | Mute |
| Upper-right | Previous track | Next track | Play or pause |
| Lower | Scroll up | Scroll down | Agent Deck |

### Window Management

Native macOS window placement, display movement, app-window navigation, Spaces, and zoom controls.

[Setup guide](setup/window-management.md)

| Position | Left | Second | Third | Right |
| --- | --- | --- | --- | --- |
| Row 1 | Left half | Right half | Top half | Bottom half |
| Row 2 | Top-left quarter | Top-right quarter | Bottom-left quarter | Bottom-right quarter |
| Row 3 | Maximize | Center | Restore size | Previous display |
| Row 4 | Next display | Minimize | Previous app window | Next app window |

| Knob | Counterclockwise | Clockwise | Press |
| --- | --- | --- | --- |
| Upper-left | Previous Space | Next Space | Mission Control |
| Upper-right | Previous window shortcut | Next window shortcut | Application Windows |
| Lower | Zoom out | Zoom in | Toggle full screen |

### Personal Automations

User-owned Apple Shortcuts routines plus keyboard navigation for the Shortcuts app.

[Setup guide](setup/personal-automations.md)

| Position | Left | Second | Third | Right |
| --- | --- | --- | --- | --- |
| Row 1 | Start Workday | End Workday | Focus Session | Break Timer |
| Row 2 | Capture Idea | New Journal Entry | Plan Today | Review Today |
| Row 3 | Open Work Apps | Close Work Apps | Meeting Setup | Meeting Wrap-up |
| Row 4 | Quiet Mode | Restore Notifications | Daily Backup | Home Arrival |

| Knob | Counterclockwise | Clockwise | Press |
| --- | --- | --- | --- |
| Upper-left | Previous shortcut | Next shortcut | Open selected shortcut |
| Upper-right | Previous section | Next section | Activate control |
| Lower | Page up | Page down | Search shortcuts |

## Development

### Agent Deck

Codex task, review, test, navigation, and reusable prompt controls.

| Position | Left | Second | Third | Right |
| --- | --- | --- | --- | --- |
| Row 1 | New task | Review changes | Run tests | Explain selection |
| Row 2 | Stop task | Summarize context | Draft commit | Find regressions |
| Row 3 | Explain failure | Plan next step | Check edge cases | Improve names |
| Row 4 | Summarize diff | Check docs | Write handoff | Ask one question |

| Knob | Counterclockwise | Clockwise | Press |
| --- | --- | --- | --- |
| Upper-left | Previous task | Next task | Open task |
| Upper-right | Previous changed file | Next changed file | Open diff |
| Lower | Scroll up | Scroll down | Desktop |

### Developer

Visual Studio Code navigation, editing, search, formatting, and task controls.

| Position | Left | Second | Third | Right |
| --- | --- | --- | --- | --- |
| Row 1 | Command palette | Quick open | New file | Open file |
| Row 2 | Save | Save all | Close editor | Reopen editor |
| Row 3 | Find | Find in files | Replace | Toggle comment |
| Row 4 | Format document | Quick fix | Go to definition | Go to references |

| Knob | Counterclockwise | Clockwise | Press |
| --- | --- | --- | --- |
| Upper-left | Move line up | Move line down | Copy line down |
| Upper-right | Previous editor | Next editor | Toggle terminal |
| Lower | Scroll editor up | Scroll editor down | Run build task |

### Git Review

Visual Studio Code source-control review, staging, history, and remote controls.

[Setup guide](setup/git-review.md)

| Position | Left | Second | Third | Right |
| --- | --- | --- | --- | --- |
| Row 1 | Source Control | Open all changes | View unstaged changes | View staged changes |
| Row 2 | View untracked changes | Git output | Stage selected ranges | Unstage selected ranges |
| Row 3 | Stage selected item | Unstage selected item | Stage all | Unstage all |
| Row 4 | Fetch | Pull | Push | View commit |

| Knob | Counterclockwise | Clockwise | Press |
| --- | --- | --- | --- |
| Upper-left | Previous change | Next change | Open selected diff |
| Upper-right | Previous editor | Next editor | Focus Source Control |
| Lower | Scroll review up | Scroll review down | Open working file |

### Terminal

Apple Terminal windows, tabs, panes, navigation, and inert command-line snippets.

[Setup guide](setup/terminal.md)

| Position | Left | Second | Third | Right |
| --- | --- | --- | --- | --- |
| Row 1 | Open Terminal | New window | New tab | Split pane |
| Row 2 | Close split pane | Find | Clear to start | Reverse history search |
| Row 3 | Git status | Git diff summary | Recent commits | Current directory |
| Row 4 | List files | Disk usage | Listening ports | Process snapshot |

| Knob | Counterclockwise | Clockwise | Press |
| --- | --- | --- | --- |
| Upper-left | Previous tab | Next tab | Show all tabs |
| Upper-right | Scroll one line up | Scroll one line down | Scroll to bottom |
| Lower | Smaller text | Larger text | Inspector |

## Work & Writing

### Research & Writing

Markdown drafting in CotEditor with focused Safari reading and Apple Notes capture controls.

[Setup guide](setup/research-writing.md)

| Position | Left | Second | Third | Right |
| --- | --- | --- | --- | --- |
| Row 1 | Open CotEditor | New draft | Open document | Save draft |
| Row 2 | Save draft as | Find in draft | Find next | Find previous |
| Row 3 | Heading | Task item | Link | Code fence |
| Row 4 | Open Safari | Safari Reader | Save to Reading List | Open Notes |

| Knob | Counterclockwise | Clockwise | Press |
| --- | --- | --- | --- |
| Upper-left | Smaller draft text | Larger draft text | Show outline |
| Upper-right | Previous Safari tab | Next Safari tab | Safari search field |
| Lower | Previous linked note | Next linked note | Search all notes |

### Meetings

Zoom Workplace meeting, sharing, recording, participant, chat, and navigation controls.

| Position | Left | Second | Third | Right |
| --- | --- | --- | --- | --- |
| Row 1 | Join meeting | Start meeting | Schedule meeting | Direct share |
| Row 2 | Mute or unmute | Start or stop video | Switch camera | Share screen |
| Row 3 | Pause sharing | Local recording | Cloud recording | Change view |
| Row 4 | Participants | Meeting chat | Invite | Copy invite link |

| Knob | Counterclockwise | Clockwise | Press |
| --- | --- | --- | --- |
| Upper-left | Previous gallery page | Next gallery page | Reactions |
| Upper-right | Read active speaker | Full screen | Minimal window |
| Lower | Raise or lower hand | Back in chat | Global search |

### Presentations

PowerPoint slide preparation and delivery, with slide, focus, and editing-zoom dials.

[Setup guide](setup/presentations.md)

| Position | Left | Second | Third | Right |
| --- | --- | --- | --- | --- |
| Row 1 | Present from start | Present current slide | Presenter View | End presentation |
| Row 2 | Black screen | White screen | Laser pointer | Arrow pointer |
| Row 3 | New slide | Duplicate slide | Undo | Redo |
| Row 4 | Save | Add comment | Insert hyperlink | Format background |

| Knob | Counterclockwise | Clockwise | Press |
| --- | --- | --- | --- |
| Upper-left | Previous slide / step | Next slide / step | Next animation |
| Upper-right | Previous object / link | Next object / link | Activate link / control |
| Lower | Editing zoom out | Editing zoom in | Fit slide |

## Media & Design

### Photo Editing

Affinity Pixel Studio retouching, selections, layers, brush size, hardness, and canvas zoom.

[Setup guide](setup/photo-editing.md)

| Position | Left | Second | Third | Right |
| --- | --- | --- | --- | --- |
| Row 1 | Undo | Redo | Save | Export |
| Row 2 | Crop | Move | Selection brush | Freehand selection |
| Row 3 | Deselect | Invert selection | Duplicate layer | New pixel layer |
| Row 4 | Copy merged | Merge visible copy | Reset colours | Swap colours |

| Knob | Counterclockwise | Clockwise | Press |
| --- | --- | --- | --- |
| Upper-left | Smaller brush | Larger brush | Paint brush |
| Upper-right | Softer brush | Harder brush | Eraser |
| Lower | Zoom out | Zoom in | Fit image |

### Video Editing

Final Cut Pro importing, timeline editing, tools, playback, navigation, and sharing using Apple defaults.

[Setup guide](setup/video-editing.md)

| Position | Left | Second | Third | Right |
| --- | --- | --- | --- | --- |
| Row 1 | Open Final Cut Pro | Import media | New project | Undo |
| Row 2 | Redo | Append | Connect | Insert |
| Row 3 | Overwrite | Blade | Blade all | Delete selection |
| Row 4 | Add marker | Default title | Transform tool | Crop tool |

| Knob | Counterclockwise | Clockwise | Press |
| --- | --- | --- | --- |
| Upper-left | Play reverse | Play forward | Stop playback |
| Upper-right | Previous frame | Next frame | Play or pause |
| Lower | Previous edit | Next edit | Share default |

### 3D Modelling

Blender object and mesh modelling with transforms, selection, editing, viewport zoom, and animation controls.

[Setup guide](setup/3d-modelling.md)

| Position | Left | Second | Third | Right |
| --- | --- | --- | --- | --- |
| Row 1 | Move | Rotate | Scale | Toggle Edit Mode |
| Row 2 | Extrude region | Inset faces | Bevel edges | Loop cut |
| Row 3 | Select all | Deselect all | Invert selection | Delete |
| Row 4 | Duplicate | Add | Hide selected | Reveal hidden |

| Knob | Counterclockwise | Clockwise | Press |
| --- | --- | --- | --- |
| Upper-left | Undo | Redo | Menu Search |
| Upper-right | Previous frame | Next frame | Play or pause |
| Lower | Zoom out | Zoom in | Frame all |

### Music Production

Logic Pro recording, project editing, track creation, key views, navigation, and arrangement zoom controls.

[Setup guide](setup/music-production.md)

| Position | Left | Second | Third | Right |
| --- | --- | --- | --- | --- |
| Row 1 | Record | Cycle Mode | Metronome | Record enable |
| Row 2 | Undo | Redo | Save | Bounce |
| Row 3 | New audio track | Instrument track | Duplicate track | Delete track |
| Row 4 | Mixer | Automation | Piano Roll | Library |

| Knob | Counterclockwise | Clockwise | Press |
| --- | --- | --- | --- |
| Upper-left | Previous track | Next track | Mute track |
| Upper-right | Rewind | Forward | Play or stop |
| Lower | Horizontal zoom out | Horizontal zoom in | Zoom selection or all |

### Recording & Streaming

OBS Studio scenes, recording, replay buffer, studio transition, and audio controls.

[Setup guide](setup/recording-streaming.md)

| Position | Left | Second | Third | Right |
| --- | --- | --- | --- | --- |
| Row 1 | Open OBS Studio | Scene 1 | Scene 2 | Scene 3 |
| Row 2 | Scene 4 | Scene 5 | Scene 6 | Scene 7 |
| Row 3 | Scene 8 | Start recording | Stop recording | Pause recording |
| Row 4 | Resume recording | Save replay | Toggle Studio Mode | Transition |

| Knob | Counterclockwise | Clockwise | Press |
| --- | --- | --- | --- |
| Upper-left | Microphone down | Microphone up | Mute microphone |
| Upper-right | Playback down | Playback up | Mute playback |
| Lower | Previous scene | Next scene | Window Management |

### Creative

Apple Preview document, image, page, zoom, and navigation controls.

| Position | Left | Second | Third | Right |
| --- | --- | --- | --- | --- |
| Row 1 | Open Preview | Save | Print | Copy selection |
| Row 2 | Cut selection | Paste into image | Next tab | Previous tab |
| Row 3 | Full screen | Previous page | Next page | Actual size |
| Row 4 | Zoom to fit | Zoom in | Zoom out | Remove background |

| Knob | Counterclockwise | Clockwise | Press |
| --- | --- | --- | --- |
| Upper-left | Scroll up a line | Scroll down a line | Previous screen |
| Upper-right | Next screen | Previous document | Next document |
| Lower | Smooth scroll up | Smooth scroll down | Desktop |
