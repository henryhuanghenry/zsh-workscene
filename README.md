# zsh-workscene

A zsh plugin for managing work scenes. Define your workspaces in a YAML config, then launch them with a single command — opens iTerm2 tabs, runs commands, and starts your editor.

## Features

- **One-command launch** — `wkc research` opens all tabs, runs commands, and starts your editor
- **YAML config** — simple, readable workspace definitions
- **iTerm2 integration** — creates named tabs and split panes via AppleScript
- **Editor support** — VS Code, CodeFlicker, or any custom editor
- **fzf selection** — run `wkc` without arguments for interactive fuzzy search
- **Tab completion** — workspace names auto-complete in zsh

## Requirements

- macOS + [iTerm2](https://iterm2.com)
- Python 3 with `PyYAML` (`pip install pyyaml`)
- [fzf](https://github.com/junegunn/fzf) (optional, for interactive selection)

## Installation

### Oh My Zsh

```bash
git clone https://github.com/henryhuanghenry/zsh-workscene ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-workscene
```

Then add `zsh-workscene` to your plugins in `~/.zshrc`:

```zsh
plugins=(... zsh-workscene)
```

### Zinit

```zsh
zinit light henryhuanghenry/zsh-workscene
```

### Antidote

```zsh
# In .zsh_plugins.txt:
henryhuanghenry/zsh-workscene
```

### Manual

```bash
git clone https://github.com/henryhuanghenry/zsh-workscene ~/.zsh-workscene
echo 'source ~/.zsh-workscene/zsh-workscene.plugin.zsh' >> ~/.zshrc
```

## Usage

```bash
wkc                # Interactive selection (requires fzf)
wkc <name>         # Launch a workspace by name
wkc list           # List all available workspaces
wkc edit           # Open config file in $EDITOR
wkc help           # Show usage info
```

## Configuration

Create `~/.zsh-workscene.yaml`:

```yaml
workspaces:
  research:
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

  work:
    tabs:
      - name: dev
        dir: ~/work/project
      - name: logs
        dir: ~/work/project
        cmd: tail -f logs/app.log
    editor:
      type: codeflicker
      path: ~/work/project
```

### Workspace Fields

| Field | Description |
|-------|-------------|
| `tabs` | List of iTerm2 tabs to open |
| `tabs[].name` | Tab title (optional) |
| `tabs[].dir` | Working directory (`~` is expanded) |
| `tabs[].cmd` | Command to run after cd (optional) |
| `tabs[].split` | List of split panes within the tab (optional) |
| `tabs[].split[].direction` | Split direction: `vertical` or `horizontal` (default: `vertical`) |
| `tabs[].split[].dir` | Working directory for the pane |
| `tabs[].split[].cmd` | Command to run in the pane (optional) |
| `editor.type` | Editor type: `vscode`, `code`, `codeflicker`, `flick` |
| `editor.path` | Path to open in editor |

### Environment Variable

| Variable | Default | Description |
|----------|---------|-------------|
| `WKC_CONFIG` | `~/.zsh-workscene.yaml` | Path to the config file |

## License

[MIT](LICENSE)
