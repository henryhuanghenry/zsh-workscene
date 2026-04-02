<div align="center">

# zsh-workscene

**Stop opening shells, IDEs, and apps one by one. Configure once, launch everything in one command.**

**告别手动逐个打开终端、编辑器和应用。通过配置记忆你的工作场景，一键全部就位。**

[![License: PolyForm Noncommercial](https://img.shields.io/badge/License-PolyForm%20Noncommercial-blue.svg)](LICENSE)
[![Platform: macOS](https://img.shields.io/badge/Platform-macOS-lightgrey.svg)](https://www.apple.com/macos)

</div>

---

### What happens when you run `wkc research`?

**Before:** You manually open terminal tabs, cd into directories, run commands, launch your editor...

**After:** One command does it all.

```
$ wkc research
🚀 Launching workspace: research
  ✓ tab: research
    ✓ split vertical: shell
  ✓ tab: logs
  ✓ editor: vscode → ~/projects/research
✅ Workspace research launched
```

This creates the following layout automatically:

```
┌─ iTerm2 ────────────────────────────────────────────────────────┐
│                                                                 │
│  [ research ]  [ logs ]                          ← tabs         │
│                                                                 │
│  ┌──────────────────────────┬───────────────────────────────┐   │
│  │                          │                               │   │
│  │  $ claude                │  $ _                          │   │
│  │  Welcome to Claude...    │  ~/projects/research          │   │
│  │                          │                               │   │
│  │  AI assistant ready      │  ready for git, build, etc.   │   │
│  │                          │                               │   │
│  └──────────────────────────┴───────────────────────────────┘   │
│           left pane                    right pane                │
│                       ↑ vertical split                          │
└─────────────────────────────────────────────────────────────────┘

┌─ VS Code ───────────────────────────────────────────────────────┐
│  📂 ~/projects/research                                         │
│  ├── src/                                                       │
│  ├── tests/                                                     │
│  └── ...                      ← editor opens project directory  │
└─────────────────────────────────────────────────────────────────┘
```

> All from a single YAML config. No scripts, no Automator, no clicking around.
>
> Any app that supports CLI or `open -a` can be auto-launched — VS Code, Obsidian, browsers, Docker Desktop, you name it.

## Interactive Selection

Run `wkc` without arguments to pick a workspace with fzf:

```
$ wkc

Config: ~/.zsh-workscene.yaml

  research    Research agent dev environment
  work        Backend API project
> deploy      Production deployment tools

  ↑/↓: select | Enter: launch | Esc: exit
```

## Features

- **One-command launch** — `wkc research` opens all tabs, runs commands, and starts your editor
- **One-command stop** — `wkc stop research` closes all tabs for a workspace
- **Environment variables** — set per-workspace env vars, auto-injected into every tab and pane
- **Workspace inheritance** — `extends` lets workspaces inherit and override a base config
- **YAML config** — simple, readable workspace definitions
- **iTerm2 integration** — creates named tabs and split panes via AppleScript
- **Editor support** — VS Code, CodeFlicker, or any app with CLI support
- **App launching** — auto-open any app via `open -a` (Obsidian, browsers, etc.)
- **fzf selection** — run `wkc` without arguments for interactive fuzzy search
- **Tab completion** — workspace names auto-complete in zsh

## Requirements

- macOS + [iTerm2](https://iterm2.com)
- Python 3 with [PyYAML](https://pypi.org/project/PyYAML/) (`pip install pyyaml`)
- [fzf](https://github.com/junegunn/fzf) (optional, for interactive selection)

## Installation

<details>
<summary><b>Oh My Zsh</b></summary>

```bash
git clone https://github.com/henryhuanghenry/zsh-workscene \
  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-workscene
```

Add to `~/.zshrc`:

```zsh
plugins=(... zsh-workscene)
```

</details>

<details>
<summary><b>Zinit</b></summary>

```zsh
zinit light henryhuanghenry/zsh-workscene
```

</details>

<details>
<summary><b>Antidote</b></summary>

```zsh
# In .zsh_plugins.txt:
henryhuanghenry/zsh-workscene
```

</details>

<details>
<summary><b>Manual</b></summary>

```bash
git clone https://github.com/henryhuanghenry/zsh-workscene ~/.zsh-workscene
echo 'source ~/.zsh-workscene/zsh-workscene.plugin.zsh' >> ~/.zshrc
```

</details>

## Quick Start

**1.** Create `~/.zsh-workscene.yaml`:

```yaml
workspaces:
  myproject:
    description: My awesome project
    tabs:
      - name: dev
        dir: ~/projects/myapp
      - name: server
        dir: ~/projects/myapp
        cmd: npm run dev
    editor:
      type: vscode
      path: ~/projects/myapp
```

**2.** Launch it:

```bash
wkc myproject
```

## Usage

```bash
wkc                   # Interactive selection (requires fzf)
wkc <name>            # Launch a workspace by name
wkc stop <name>       # Stop a workspace (close its tabs)
wkc list              # List all available workspaces
wkc edit              # Open config file in $EDITOR
wkc help              # Show usage info
```

## Configuration

### Full Example

```yaml
workspaces:
  research:
    description: Research agent dev environment
    env:
      OPENAI_API_KEY: sk-xxx
      NODE_ENV: development
    tabs:
      - name: claude
        dir: ~/projects/research
        cmd: claude
        split:
          - direction: vertical
            dir: ~/projects/research
    editor:
      type: vscode
      path: ~/projects/research

  writing:
    description: Writing workspace with Obsidian
    tabs:
      - name: notes
        dir: ~/notes
        cmd: open -a "Obsidian"
    editor:
      type: vscode
      path: ~/notes

  work:
    description: Backend API project
    tabs:
      - name: dev
        dir: ~/work/project
      - name: logs
        dir: ~/work/project
        cmd: tail -f logs/app.log
    editor:
      type: vscode
      path: ~/work/project

  work-fe:
    description: Frontend (inherits from work)
    extends: work
    editor:
      type: vscode
```

### Reference

| Field | Description |
|-------|-------------|
| `description` | Brief description shown in fzf selector (optional) |
| `extends` | Name of parent workspace to inherit from (optional) |
| `env` | Key-value map of environment variables to export (optional) |
| `tabs` | List of iTerm2 tabs to open |
| `tabs[].name` | Tab title (optional) |
| `tabs[].dir` | Working directory (`~` is expanded) |
| `tabs[].cmd` | Command to run after cd (optional) |
| `tabs[].split` | List of split panes within the tab (optional) |
| `tabs[].split[].direction` | `vertical` or `horizontal` (default: `vertical`) |
| `tabs[].split[].dir` | Working directory for the pane |
| `tabs[].split[].cmd` | Command to run in the pane (optional) |
| `editor.type` | `vscode` / `code` / `codeflicker` / `flick` |
| `editor.path` | Path to open in editor |

> **Tip:** Use `cmd: open -a "AppName"` in any tab to launch macOS apps like Obsidian, Chrome, Docker Desktop, etc.

### Environment Variable

| Variable | Default | Description |
|----------|---------|-------------|
| `WKC_CONFIG` | `~/.zsh-workscene.yaml` | Path to the config file |

## License

[PolyForm Noncommercial 1.0.0](LICENSE) — free for personal and non-commercial use. For commercial licensing, please contact the author.
