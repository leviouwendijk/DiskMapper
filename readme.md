# DiskMapper

## Opening shared files, (where you want)

Allows you to stop exchanging redundant copies of files by using a common file path reference. Requires you both to host the same file at the same location, relative to root -- (trivial, if using iCloud).

DiskMapper currently comes with a CLI (`diskmap` invocation), and background process application.

It enables you to set a root target, and resolve files the way you like. Meaning, if you prefer a terminal running a certain text editor, and someone else prefers to see it in Finder, you don't have to compromise.

## Quick Guide

### Using CLI

Get link for a file (auto-copies to clipboard):
```
diskmap get "shared/test.md"
```

Get link for file, and append it to configured root:
```
diskmap get "shared/test.md" --pr
```

Get link for a file:
```
diskmap get "shared/test.md"
```

Process a generated url (open):
```
diskmap process --url "diskmap://?rel=shared/test%20space.md"
```

### Manual writing

This is designed for making it stupidly simple to share a filepath. Links are kept relative for this reason.

You should be able to handwrite it without hassle.

So, if your path is simple (and you are not in your terminal), you may just want to build it out by hand:

1: `diskmap://`
2: `?rel=`
3: `example/test-file.md`

Note that this is easier if you avoid a lot of nesting, using spaces (`%20`), or capitals.

Tips, accordingly:
- Use dash or underscore for a space, and don't capitalize, not spaces (do: `dir/my-file.txt`, not: `Dir/My File.txt`).
- Avoid nesting and long file names where you can (do: `shared/project/goals.md`, not: `shared-directory/our-grand-project/a-list-of-goals-overview.md`).


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

