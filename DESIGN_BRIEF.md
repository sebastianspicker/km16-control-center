# Design brief: KM16 Control Center

Date: 2026-09-27. Branch: `redesign/legend-card`.

## 1. Product

KM16 Control Center is a macOS profile editor and action launcher for the
MMD KM16 Pro, an inexpensive wireless macro pad with 16 keys and three rotary
knobs. On the Mac, a profile assigns an action to each of 25 inputs: 16 keys,
plus a counterclockwise turn, a clockwise turn, and a press for each knob. An
action is a shortcut, a text snippet, a system or media action, an app launch,
a profile switch, a shell process, an agent (Codex) prompt, or an OBS operation.

The repository holds three things of equal seriousness:

1. The **native Mac app** (SwiftUI, macOS 14). It has a sidebar with profiles,
   a drawing of the pad, an assignment inspector, Preview/Run, Connections (OBS
   and Codex), and a Preset Library.
2. The **browser demo** (`site/`, GitHub Pages). It is the project's only public
   web surface. It lets anyone browse the 16 factory presets and their 400
   assignments on a drawing of the pad, edit them in memory, and "preview"
   them. All of it is simulated.
3. The **hardware research**: reverse-engineered HID reports, firmware readback,
   and knob mapping. Every finding carries its provenance.

**Moment of value.** You pick a preset such as *Video Editing* and see all 25
inputs of your pad labelled at once. The question "what would this pad do for me?"
is answered at a glance. The second moment is selecting one control and seeing
exactly what it sends (`cmd+shift+4`, a bundle ID, a JSON process payload)
before anything runs.

## 2. Audience

**Primary.** A technically fluent Mac user who owns, or is thinking about
buying, a KM16 Pro. They build the app from source (it needs a Swift 6
toolchain), so they are developers, or creative professionals who are
comfortable in a terminal: editors, producers, streamers, and researchers who
write. They use tools like VS Code, Terminal, Final Cut or Resolve, Logic or
Ableton, OBS, Obsidian, and Shortcuts every day.

- *Goals:* make a cheap pad genuinely useful on macOS without the vendor's
  Windows-first utility; understand exactly what each control does.
- *Anxieties:* a profile silently running a shell command; vendor software
  phoning home; losing edits; hardware claims that turn out to be wishful.
- *Distrusts:* marketing gloss, "AI-powered" language, fake screenshots,
  vague claims.
- *Reads as quality:* precision, honest labelling of limits, real data instead
  of lorem ipsum, keyboard-first operation, dense information that still scans,
  and craft in small details (tabular numbers, correct modifier glyphs).

**Secondary.** Curious visitors to the repository page who follow the demo link.
They need to understand in about ten seconds what the pad is and what the app
does.

## 3. Key journeys (demo = primary web journey)

1. Arrive → understand what this is and that it is a simulation → see a full
   pad labelled with a real preset.
2. Browse presets by group (Everyday, Development, Work & Writing, Media &
   Design) and search by name or summary.
3. Select a key or knob input → read its assignment: name, kind, payload, target
   app, description.
4. Edit the name or payload in memory → see the pad update.
5. Preview → see a log line recording what *would* happen; nothing runs.
6. Reset to factory presets. Recover from a failed preset load (retry).

## 4. Brand traits

| Trait | Not |
| --- | --- |
| **Exact**: labels say precisely what happens | pedantic or cluttered |
| **Candid**: states limits (simulation, unverified hardware) in plain view | apologetic or legalistic |
| **Workmanlike**: a tool drawn by someone who uses it daily | drab, or "enterprise" |
| **Tactile**: remembers there is a physical object with keys and knobs | skeuomorphic kitsch |
| **Quietly independent**: an unofficial companion with its own voice | anti-vendor snark, hacker cosplay |

## 5. Market observations

The nearest alternatives are Elgato Stream Deck, Loupedeck/Logitech MX Creative
Console, Razer Synapse, VIA/Vial (QMK keyboards), Karabiner-Elements and BetterTouchTool,
and the vendors' own macro-pad utilities. This is reasoned from knowledge of the
category; the live sites were not re-checked.

- **Conventions to keep:** the device drawn as its real layout, with each control
  selected directly on the drawing. A persistent inspector for the selected
  control. Profiles grouped by use. Modifier glyphs (⌘⇧⌥⌃) for shortcuts. Users
  rely on these conventions.
- **Conventions to break:**
  - *Gamer/stream darkness:* near-black UI, neon accents, and RGB glow (Synapse,
    Stream Deck marketing). Our user is at a desk working, not on stage.
  - *Icon soup:* every key shows only an icon, so you must hover to learn what it
    does. VIA/Vial show raw keycodes, which is exact but unreadable.
  - *Fake device-window chrome:* marketing pages that wrap the tool in a fake
    macOS window. The current demo does exactly this, down to traffic lights.
  - *Uniform accent:* one system-blue for everything, so selection, hover, and
    kind all look alike.

## 6. What exists (current state)

- **Demo stack:** static `index.html`, `styles.css`, `app.js` (vanilla, no build),
  data from `presets/all.json`. Strict CSP (`default-src 'none'`, `self` only).
  `scripts/build-site.py` publishes an allowlist of files.
- **Styling:** about 1,100 lines of hand-written CSS without tokens. There are
  roughly 60 distinct grays, font sizes from 6 to 36 px (several below 9 px),
  system font, and system blue `#087dfa`.
- **Visual language:** a fake macOS window (traffic lights, title bar), a
  white-gray gradient pad, and keys that each show a Unicode "kind" glyph
  (⌘, ▢, ⌁, ✧) and a label.
- **Brand assets:** no logo beyond a favicon of a blue key grid. The name
  "KM16" is the only brand equity. There is no signature color worth keeping:
  it is the system blue.
- **Mac app:** idiomatic SwiftUI with `NavigationSplitView`, an inspector,
  toolbar, and SF Symbols. `DesignSystem.swift` (`StudioStyle`) holds the symbol
  maps and the surface modifier. The pad is drawn in `ConfiguratorView.swift`
  (`PadSurface`, `StudioKeycap`, `StudioDial`).

**Worth keeping:** the pad-as-interface idea, the grouping, the honest copy
(most of it is good), the keyboard shortcut ⌘↩, the favicon's key-grid motif,
and native macOS chrome in the app. Mac users expect the app to look like a Mac
app.

**Weaknesses:**
- **Unreadable text:** 6–9 px type throughout the demo (key numbers, dial
  labels, notes). This fails legibility and WCAG in spirit, and contrast
  (`#999da5` on white is 2.7:1) in fact.
- **Hidden meaning:** keys show a kind glyph that repeats ⌘ on 279 of 400
  assignments, so the glyph carries almost no information. The actual keystroke
  (the most useful fact) is hidden in the inspector.
- **Hidden turns:** knob turns are two anonymous ↶ ↷ buttons. You cannot see
  what a knob does without clicking every arrow.
- **Borrowed identity:** a fake window frame and system blue; nothing is
  specific to this product.
- **Weak mobile:** the mobile layout collapses the desktop layout, with 6 px
  labels and 20 px-wide turn buttons.
- **No dark mode** in the demo.

## 7. Constraints (load-bearing)

- The demo must stay a simulation. Keep simulation labels visible and add no
  real desktop, service, or network access. Keep the strict CSP and the
  `build-site.py` allowlist, which the tests enforce. Any new published file must
  be added to the allowlist deliberately.
- `site/app.js` must keep the `groups` array literal in its current textual shape:
  `SiteParityTests` parses it with a regex (`['Title', ['id', …]]` rows).
- Data contract: `presets.json` (`profiles[].bindings[].controlID/action{label,kind,parameter,detail,targetBundleID}`),
  control IDs `key-R-C` and `encoder-N-{ccw,cw,press}`, validation of all 25
  inputs, retry on load failure.
- Behaviour to keep: search, group headings, selecting a preset resets selection
  to Key 1, in-memory name/payload edits, Preview log, Reset, and mobile preset
  toggle (`aria-expanded`).
- Mac app: preserve all functionality, bundle ID, accessibility labels, and
  keyboard shortcuts. The app must build with the Command Line Tools setup and
  pass `swift test`.
- `bash scripts/verify-source.sh` must exit 0.
- Fonts must be open-licensed and self-hosted, because the CSP forbids third-party
  origins; a public demo that promises "nothing is sent" should not call Google
  either.

## 8. Assumptions log

| # | Assumption | Evidence | Confidence |
| --- | --- | --- | --- |
| A1 | The browser demo is the "website" to redesign end to end; the Mac app is the "product" and gets the same identity on its pad drawing while keeping native chrome. | The demo is the only web surface; the app follows macOS HIG, and replacing native chrome would hurt Mac users. | high |
| A2 | Primary users are technical Mac users who build from source. | README requires a Swift 6 toolchain; presets target VS Code, Terminal, Git, Codex, OBS. | high |
| A3 | Users value seeing the actual keystroke or payload over an icon. | 279 of 400 assignments are shortcuts; VIA/QMK users routinely read keycodes; the inspector already shows the ⌘ string large. | medium |
| A4 | Colour-coding action kinds by *consequence* (types / system / opens / runs) is meaningful and not just decorative. | Import and README copy repeatedly warn that profiles "can contain commands, text, and agent prompts"; shell, agent, and OBS actions are the ones that affect other processes. | medium |
| A5 | Light mode is the primary appearance, with dark mode as a first-class alternative. | Desk-work audience; app screenshots are in light mode; the site had no dark mode. | medium |
| A6 | Most visitors arrive from the GitHub README on desktop; mobile visitors want to browse presets, not edit payloads. | Demo linked from README; editing JSON payloads on a phone is rare. | medium |
| A7 | The physical pad is dark or neutral; its real colours do not matter to the design. | No case colour is recorded in the repo; LED colours vary by layer. | low: the design deliberately avoids depicting case colour. |
| A8 | The repository URL `github.com/sebastianspicker/km16-control-center` is public and fine to link from the demo. | `git remote`; the README links the Pages URL under the same account. | high |

---

## 9. Design direction

### The domain, mined

A macro pad is a descendant of two older artifacts:

- **The keyboard template card.** In the 1980s, software came with a printed
  cardboard overlay for the function keys, the WordPerfect template being the
  famous one. Each key's legend was printed in a colour that told you *which
  modifier* produced it. It was the first "profile": a sheet of paper
  that told your hands what the keys meant in this program. People swapped
  templates when they swapped programs, exactly as KM16 profiles are swapped per app.
- **The engraved control panel.** The knobs are encoders whose scales are printed
  around them: a legend for each direction.

Also in the domain: keycap legends (printed text on a key), the key *matrix*
(rows × columns), HID usage tables, and the research notebook's habit of saying
what was *observed* versus *inferred*.

### Direction A: "Legend Card" (chosen)

**Concept.** Each profile is a printed template card laid over the pad. The page
*is* the card. Every key carries its real legend: the action name, set in
condensed capitals, and beneath it the literal code it sends (`⌘⇧4`, `Finder`,
`sh`), in mono. Each knob is printed with its legends: ◂ counterclockwise, ▸
clockwise, and ● press. Legends are printed in one of four inks, and the ink
tells you the *consequence*, just as template colours once told you the modifier:

| Ink | Means | Kinds |
| --- | --- | --- |
| Carbon | types into the front app | shortcut, text snippet |
| Cobalt | adjusts the Mac | system: media, volume, windows, scroll |
| Green | opens or goes somewhere | launch app, switch profile |
| Vermilion | runs something outside the app | shell, agent (Codex), OBS |

Vermilion doubles as the "handle with care" colour the app's safety copy has
always asked for, and that the design has never shown. Ink is never the only
signal: every legend also carries a short kind code (`KEY`, `TXT`, `SYS`, `APP`,
`PRF`, `SH`, `AGT`, `OBS`).

- **Why it fits:** it is exact (you read the actual keystroke), tactile
  (template on a device), workmanlike (a reference card, not a showpiece), and
  candid (consequence is visible before you click). The concept comes from the
  product's own ancestry, not from a trend.
- **Typography:** *Archivo* (variable, OFL), which runs from 62 to 125 % width
  and 100 to 900 weight in one file. Condensed caps (`wdth` 68–75, wght 600)
  for legends and labels, the way template cards and panel engravings were
  set. Wider and heavier (`wdth` 112, wght 800) for the profile name, which
  reads like the title printed on the card's header strip. *Fragment Mono* (OFL)
  for codes, payloads, control IDs, and log lines. Two families, one variable
  file each, and no third face. Scale (px): 12 / 13 / 15 / 18 / 24 / 40 / 64,
  a roughly 1.3 step. The floor is 12 px, with nothing smaller anywhere.
- **Colour:** paper `#F3F1EA`, card `#FBFAF6`, carbon ink `#1C1B18`, graphite
  secondary text `#5B5850`, rules `#D8D4C8`, and four legend inks: cobalt
  `#1F4FC1`, green `#1D6B45`, vermilion `#C23B17`, plus carbon. Selection uses
  a *registration* marker: a heavy carbon frame with corner ticks, the printer's
  crop marks, not a blue glow. Dark mode is the same card printed in reverse:
  warm charcoal `#1A1916`, inks lifted to pass AA on it.
- **Layout:** a 12-column page grid with a fixed rhythm of 8 px. On desktop:
  a preset index (numbered 01–16, like a catalogue) | the card (dominant, about 60 %
  of the width) | the legend entry (the inspector, set like a dictionary entry).
  Below that, a full-width *log tape*. The card is the only boxed object on the page;
  everything else is separated by hairline rules, not by panels and shadows.
  Density is high but set on a baseline, like a reference card.
- **Mobile:** it is not a squeezed desktop. The card becomes the whole
  screen: 4 × 4 legends at about 84 px, knobs as a single row of three printed
  dials. The preset index becomes a full-height sheet behind a sticky "preset"
  bar showing the current preset. The inspector follows the card, and
  selecting a control on a phone scrolls the entry into view.
- **Motion:** very little, and each movement is a meaning, not a flourish.
  Previewing a knob turn rotates that knob's pointer 30° in that direction.
  Previewing a key presses the key down 2 px for 120 ms. The log line prints in
  by a 160 ms opacity change. The selection frame snaps without sliding. All of it
  is off under `prefers-reduced-motion`.
- **Signature details:**
  1. Legends show the real code (`⌘⇧4`) under the name, which no competitor does
     on the device drawing.
  2. Printed knob scales with the three legends set around each dial.
  3. Registration-mark selection frame.
- **Stands apart by:** paper instead of gamer black; consequence-coded inks
  instead of a single accent; and text legends instead of icon soup.
- **Refuses:** fake window chrome, drop shadows as depth, rounded "cards" for
  every group, gradients, glow, emoji or icon fonts, hero sections, and marketing
  copy.

### Direction B: "Bench Notebook"

**Concept.** The research lab notebook: the demo as a spread from an engineer's
notebook, with numbered figures ("Fig. 3 — Upper-right knob, CW"), marginal
annotations that separate *observed* from *inferred*, and a datasheet-style
pinout of the pad where each control is a callout line to its assignment.

- **Typography:** *Newsreader* (serif, OFL) for prose and figure captions;
  *IBM Plex Mono* for callouts.
- **Colour:** off-white graph paper, black ink, one annotation red.
- **Layout:** an asymmetric two-column spread with wide margins; the pad at
  the centre with callout leader lines fanning out to 25 labels.
- **Motion:** leader lines draw on selection.
- **Signature details:** callout leaders, and figure numbering.
- **Stands apart by** reading like documentation, not like software.
- **Refuses:** any UI chrome at all.
- **Weakness:** 25 callouts do not fit on mobile. It privileges the research
  over the everyday editor, and it turns an *interactive tool* into an
  illustration; editing and previewing feel bolted on.

### Direction C: "Channel Strip"

**Concept.** The pad as a mixing-console channel strip: dark anodised panel,
engraved labels, knobs with detailed skirts, and LED-style state indicators.
It borrows from the music and streaming users in the preset list.

- **Typography:** *Space Grotesk* plus a DIN-like condensed face for engraving.
- **Colour:** charcoal panel, cream engraving, amber indicator.
- **Layout:** a vertical strip-based layout, dense and hardware-literal.
- **Motion:** knobs turn with the mouse wheel; indicator LEDs light on preview.
- **Signature details:** knob skirts, and LED state.
- **Stands apart by** looking like hardware rather than like a web app.
- **Refuses:** light mode.
- **Weakness:** it is the category's dark-and-glowing cliché in a nicer suit.
  Skeuomorphic knob skirts age fast. Only four of sixteen presets are
  audio/video, so it misreads the audience, and dark-only fails A5.

### Decision

**A: Legend Card.** It is the only direction whose organising idea *improves the
product*, not just its surface: showing the real code and colour-coding
consequence make the pad more understandable and safer to use. It scales from a
390 px phone (a 4 × 4 card is naturally square) to the Mac app, where the same
legend treatment applies to the native pad drawing without disturbing macOS
chrome.

**Traded away:** B's research voice. We keep a little of it: a
"what's simulated / what's real" note in the footer that separates the two
honestly. We also give up C's hardware drama. Condensed caps legends risk
feeling cramped with long labels. The longest factory label is 24 characters,
so legends wrap to two lines and fall back to a tighter width, never to smaller
than 12 px. If A3 is wrong (users prefer icons), the code line is a secondary
line that can be dropped without breaking the layout.
