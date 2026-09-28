# Git Review: Visual Studio Code

This preset targets Visual Studio Code (`com.microsoft.VSCode`). It has no automatic app match because the Developer preset uses the same app.

VS Code assigns `Control-Shift-G` to Source Control by default. Several other controls need the bindings supplied in `keybindings/git-review.code-keybindings.json` (next to this guide):

1. In VS Code, run Preferences: Open Keyboard Shortcuts (JSON) from the Command Palette.
2. Keep the existing outer JSON array and all existing entries.
3. Copy only the objects inside the fragment's `[` and `]` into the existing array. Add a comma before the first copied object when needed.
4. Search the resulting file for each `ctrl+alt+shift` chord. Resolve any conflict intentionally before using the preset.
5. Open a Git repository and verify Source Control, Open all changes, Stage selected item, Git output, and each dial before using remote actions.

Do not replace `keybindings.json` with the fragment. Fetch, Pull, and Push are keys, so turning a dial cannot start network activity. These controls still use VS Code's normal prompts, repository selection, authentication, and safeguards. The dials move through changes and editors, focus Source Control, scroll reviews, and open the selected diff or working file.

References:

- [VS Code keyboard shortcuts for macOS](https://code.visualstudio.com/shortcuts/keyboard-shortcuts-macos.pdf)
- [Source control in VS Code](https://code.visualstudio.com/docs/sourcecontrol/overview)
- [Built-in Git command declarations](https://github.com/microsoft/vscode/blob/main/extensions/git/package.json)
