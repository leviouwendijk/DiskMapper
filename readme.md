# DiskMapper

## Opening shared files, (where you want)

Allows you to stop exchanging redundant copies of files by using a common file path reference. Requires you both to host the same file at the same location, relative to root -- (trivial, if using iCloud).

DiskMapper currently comes with a CLI (`diskmap` invocation), and background process application.

It enables you to set a root target, and resolve files the way you like. Meaning, if you prefer a terminal running a certain text editor, and someone else prefers to see it in Finder, you don't have to compromise.

## Setup / Config 

Place a `config.json` in one of these paths:
    `<home>/dotfiles/disk-mapper/config.json`
    `<home>/disk-mapper/config.json`

These are the current configuration options:

```json
{
    "root": "/Users/leviouwendijk/Library/Mobile Documents/com~apple~CloudDocs/Shared Files/Hondenmeesters",
    "preferred_open_method": "terminal | finder | system_default",
    "terminal": {
        "terminal_application": "/Applications/Ghostty.app",
        "default_action": {
            "file": {
                "use_command": "nvim",
                "arguments": []
            },
            "directory": {
                "use_command": "nvim",
                "arguments": []
            }
        }
    },
    "finder": {
        "default_action": {
            "file": "view (only views in finder window, even when file) | edit (opens in preferred text editor)",
            "text_editor": "example: TextEdit | Sublime"
        }
    },
    "safe_restrict_to_root": true
}
```

