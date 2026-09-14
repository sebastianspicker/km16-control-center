# Personal Automations: Apple Shortcuts

This preset targets Apple Shortcuts (`com.apple.shortcuts`) but does not include personal routines. Its 16 keys call `/usr/bin/shortcuts run` with the exact names below. Create and review each shortcut before use. A missing name produces a visible command failure; if you prefer another name, rename either the shortcut or its preset action.

The recipes are starting points. Choose every app, folder, contact, Focus, Home item, and destination yourself; the preset contains no personal path, account, or recipient.

| Exact shortcut name | Suggested actions to add in order |
| --- | --- |
| Start Workday | **Set Focus** to a work Focus until turned off; add one **Open App** action for each app you choose; finish with **Show Notification**. |
| End Workday | Add one **Quit App** action for each work app you choose; use **Set Focus** to turn the work Focus off; finish with **Show Notification**. |
| Focus Session | **Ask for Input** for minutes as a number; calculate the end time with **Adjust Date**; **Set Focus** until that time; **Start Timer** for the entered duration. |
| Break Timer | **Start Timer** for a fixed break length you choose; **Show Notification** with the planned return time. |
| Capture Idea | **Ask for Input** as text; **Create Note** in a Notes folder you select; **Show Notification** after saving. |
| New Journal Entry | **Current Date**; **Format Date** with your preferred heading format; **Ask for Input** for the entry; combine both with **Text**; **Create Note** in a journal folder you select. |
| Plan Today | **Find Calendar Events** whose start date is today; **Find Reminders** due today; combine their titles with **Text**; display them with **Quick Look**. |
| Review Today | **Find Calendar Events** from today; **Find Reminders** completed today; combine the results with **Text**; display them with **Quick Look**. |
| Open Work Apps | Add an **Open App** action for each user-selected work app, in the order you want them opened. |
| Close Work Apps | Add a **Quit App** action for each user-selected work app; end with **Show Notification** so completion is visible. |
| Meeting Setup | **Set Focus** to a meeting Focus; add **Open App** actions for the calendar, notes, and meeting apps you choose; finish with **Show Notification**. |
| Meeting Wrap-up | **Ask for Input** for follow-up notes; **Create Note** in a folder you select; **Set Focus** to turn the meeting Focus off. |
| Quiet Mode | **Set Focus** to Do Not Disturb until turned off; optionally use **Set Volume** with a level you choose; finish with **Show Notification**. |
| Restore Notifications | **Set Focus** to turn the current Focus off; optionally use **Set Volume** with your normal level; finish with **Show Notification**. |
| Daily Backup | **Get Contents of Folder** for a folder you select; **Make Archive**; **Save File** to a destination you select during setup with overwrite behavior set explicitly. |
| Home Arrival | Use **Choose from Menu** for the Home scenes or actions you personally allow; place the corresponding **Control Home** action in each menu branch; finish with **Show Notification**. |

Command-line runs may pause for input or privacy permission. Run each shortcut once in the Shortcuts app, grant only the access it needs, and decide whether its prompts are acceptable. KM16 Control Center stops the process after five minutes.

The dials use standard keyboard navigation in Shortcuts: arrows choose items, Return opens, Tab and Shift-Tab move focus, Space activates the focused control, Page Up and Page Down scroll, and Command-F searches. Turn on System Settings > Keyboard > Keyboard navigation if Tab does not reach the expected controls.

References:

- [Create a custom shortcut on Mac](https://support.apple.com/guide/shortcuts-mac/create-a-custom-shortcut-apd84c576f8c/mac)
- [Navigate the action list in Shortcuts](https://support.apple.com/guide/shortcuts-mac/navigate-the-action-list-apdc33e4f4da/mac)
- [Run shortcuts from the command line](https://support.apple.com/guide/shortcuts-mac/apd455c82f02/mac)
- [Run a shortcut from the Shortcuts app](https://support.apple.com/guide/shortcuts-mac/run-a-shortcut-from-the-app-apd5ba077760/mac)
