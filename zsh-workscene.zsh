# zsh-workscene — work scene manager for iTerm2
# https://github.com/henryhuanghenry/zsh-workscene
# v0.2.0
# Copyright (c) 2026 henryhuanghenry
# PolyForm Noncommercial 1.0.0 — see LICENSE file for details.

WKC_CONFIG="${WKC_CONFIG:-$HOME/.zsh-workscene.yaml}"

#--------------------------------------------------------------------#
# YAML Config Parser (Python)                                        #
#--------------------------------------------------------------------#

_wkc_parse() {
  python3 -c "
import yaml, json, sys, os, copy

config_path = os.path.expanduser('$WKC_CONFIG')
if not os.path.exists(config_path):
    print('ERROR: config not found: ' + config_path, file=sys.stderr)
    sys.exit(1)

with open(config_path) as f:
    data = yaml.safe_load(f)

workspaces = data.get('workspaces', {})

def deep_merge(base, override):
    result = copy.deepcopy(base)
    for k, v in override.items():
        if k == 'extends':
            continue
        if k in result and isinstance(result[k], dict) and isinstance(v, dict):
            result[k] = deep_merge(result[k], v)
        else:
            result[k] = copy.deepcopy(v)
    return result

def resolve(name, seen=None):
    if seen is None:
        seen = set()
    if name in seen:
        print('ERROR: circular extends: ' + name, file=sys.stderr)
        sys.exit(1)
    seen.add(name)
    ws = workspaces.get(name)
    if ws is None:
        print('ERROR: workspace not found: ' + name, file=sys.stderr)
        sys.exit(1)
    parent = ws.get('extends')
    if parent:
        base = resolve(parent, seen)
        return deep_merge(base, ws)
    return copy.deepcopy(ws)

cmd = sys.argv[1] if len(sys.argv) > 1 else 'list'

if cmd == 'list':
    for name in workspaces:
        print(name)
elif cmd == 'list_detail':
    for name, ws in workspaces.items():
        desc = ws.get('description', '')
        if desc:
            print(f'{name}\t{desc}')
        else:
            print(name)
elif cmd == 'get':
    name = sys.argv[2]
    result = resolve(name)
    print(json.dumps(result))
" "$@"
}

#--------------------------------------------------------------------#
# iTerm2 Tab Management (AppleScript)                                #
#--------------------------------------------------------------------#

_wkc_open_tab() {
  local dir="$1"
  local cmd="$2"
  local tab_name="$3"
  local env_script="$4"

  # Expand ~
  dir="${dir/#\~/$HOME}"

  local script=""
  if [[ -n "$env_script" ]]; then
    script="${env_script} && "
  fi
  script="${script}cd ${dir}"
  if [[ -n "$cmd" ]]; then
    script="${script} && ${cmd}"
  fi

  osascript <<EOF
tell application "iTerm2"
  tell current window
    create tab with default profile
    tell current session of current tab
      write text "${script}"
    end tell
  end tell
end tell
EOF

  # Set tab title
  if [[ -n "$tab_name" ]]; then
    osascript <<EOF
tell application "iTerm2"
  tell current window
    tell current tab
      tell current session
        set name to "${tab_name}"
      end tell
    end tell
  end tell
end tell
EOF
  fi
}

#--------------------------------------------------------------------#
# iTerm2 Split Pane (AppleScript)                                    #
#--------------------------------------------------------------------#

_wkc_split_pane() {
  local direction="$1"  # vertical or horizontal
  local dir="$2"
  local cmd="$3"
  local env_script="$4"

  # Expand ~
  dir="${dir/#\~/$HOME}"

  local script=""
  if [[ -n "$env_script" ]]; then
    script="${env_script} && "
  fi
  script="${script}cd ${dir}"
  if [[ -n "$cmd" ]]; then
    script="${script} && ${cmd}"
  fi

  osascript <<EOF
tell application "iTerm2"
  tell current window
    tell current session of current tab
      split ${direction}ly with default profile
    end tell
    tell current session of current tab
      write text "${script}"
    end tell
  end tell
end tell
EOF
}

#--------------------------------------------------------------------#
# Workspace Stop (close tabs by name)                                #
#--------------------------------------------------------------------#

_wkc_stop() {
  local name="$1"
  local config
  config=$(_wkc_parse get "$name") || return 1

  # Collect tab names
  local tab_names
  tab_names=$(python3 -c "
import json, sys
data = json.loads(sys.argv[1])
tabs = data.get('tabs', [])
for tab in tabs:
    n = tab.get('name', '')
    if n:
        print(n)
" "$config")

  if [[ -z "$tab_names" ]]; then
    echo "wkc: no named tabs found for workspace: $name" >&2
    return 1
  fi

  echo "🛑 Stopping workspace: $name"

  echo "$tab_names" | while read -r tname; do
    osascript <<EOF
tell application "iTerm2"
  tell current window
    set tabList to tabs
    repeat with i from (count of tabList) to 1 by -1
      set t to item i of tabList
      repeat with s in sessions of t
        if name of s is "${tname}" then
          close t
          exit repeat
        end if
      end repeat
    end repeat
  end tell
end tell
EOF
    echo "  ✓ closed tab: $tname"
  done

  echo "✅ Workspace $name stopped"
}

#--------------------------------------------------------------------#
#--------------------------------------------------------------------#

_wkc_open_editor() {
  local editor_type="$1"
  local editor_path="$2"

  # Expand ~
  editor_path="${editor_path/#\~/$HOME}"

  case "$editor_type" in
    vscode|code)
      code "$editor_path"
      ;;
    codeflicker|flick)
      flick "$editor_path"
      ;;
    *)
      echo "wkc: unknown editor type: $editor_type" >&2
      ;;
  esac
}

#--------------------------------------------------------------------#
# Workspace Launcher                                                 #
#--------------------------------------------------------------------#

_wkc_launch() {
  local name="$1"
  local config
  config=$(_wkc_parse get "$name") || return 1

  echo "🚀 Launching workspace: $name"

  # Parse env variables
  local env_script
  env_script=$(python3 -c "
import json, sys
data = json.loads(sys.argv[1])
env = data.get('env', {})
parts = []
for k, v in env.items():
    parts.append(f'export {k}={v}')
print(' && '.join(parts))
" "$config")

  # Parse tab count
  local tab_count
  tab_count=$(python3 -c "
import json, sys
data = json.loads(sys.argv[1])
tabs = data.get('tabs', [])
print(len(tabs))
" "$config")

  local i=0
  while (( i < tab_count )); do
    local tab_info
    tab_info=$(python3 -c "
import json, sys, os
data = json.loads(sys.argv[1])
tab = data['tabs'][int(sys.argv[2])]
dir_path = tab.get('dir', '~')
cmd = tab.get('cmd', '')
name = tab.get('name', '')
split_list = json.dumps(tab.get('split', []))
print(dir_path)
print(cmd)
print(name)
print(split_list)
" "$config" "$i")

    local tab_dir tab_cmd tab_name split_json
    tab_dir=$(echo "$tab_info" | sed -n '1p')
    tab_cmd=$(echo "$tab_info" | sed -n '2p')
    tab_name=$(echo "$tab_info" | sed -n '3p')
    split_json=$(echo "$tab_info" | sed -n '4p')

    _wkc_open_tab "$tab_dir" "$tab_cmd" "$tab_name" "$env_script"
    echo "  ✓ tab: ${tab_name:-$tab_dir}"

    # Handle split panes within this tab
    local split_count
    split_count=$(python3 -c "import json,sys; print(len(json.loads(sys.argv[1])))" "$split_json")
    local j=0
    while (( j < split_count )); do
      local pane_info
      pane_info=$(python3 -c "
import json, sys
splits = json.loads(sys.argv[1])
p = splits[int(sys.argv[2])]
print(p.get('direction', 'vertical'))
print(p.get('dir', '~'))
print(p.get('cmd', ''))
" "$split_json" "$j")

      local pane_dir pane_cmd pane_direction
      pane_direction=$(echo "$pane_info" | sed -n '1p')
      pane_dir=$(echo "$pane_info" | sed -n '2p')
      pane_cmd=$(echo "$pane_info" | sed -n '3p')

      _wkc_split_pane "$pane_direction" "$pane_dir" "$pane_cmd" "$env_script"
      echo "    ✓ split ${pane_direction}: ${pane_cmd:-shell}"
      (( j++ ))
    done

    (( i++ ))
  done

  # Open editor
  local editor_info
  editor_info=$(python3 -c "
import json, sys
data = json.loads(sys.argv[1])
editor = data.get('editor')
if editor:
    print(editor.get('type', ''))
    print(editor.get('path', ''))
else:
    print('')
    print('')
" "$config")

  local editor_type editor_path
  editor_type=$(echo "$editor_info" | sed -n '1p')
  editor_path=$(echo "$editor_info" | sed -n '2p')

  if [[ -n "$editor_type" && -n "$editor_path" ]]; then
    _wkc_open_editor "$editor_type" "$editor_path"
    echo "  ✓ editor: $editor_type → $editor_path"
  fi

  echo "✅ Workspace $name launched"
}

#--------------------------------------------------------------------#
# Main Command                                                       #
#--------------------------------------------------------------------#

wkc() {
  case "$1" in
    list)
      echo "Available workspaces:"
      _wkc_parse list | while read -r name; do
        echo "  - $name"
      done
      ;;
    edit)
      ${EDITOR:-vim} "$WKC_CONFIG"
      ;;
    help|--help|-h)
      echo "Usage: wkc [name|list|stop|edit]"
      echo ""
      echo "  wkc              Interactive selection (requires fzf)"
      echo "  wkc <name>       Launch a workspace"
      echo "  wkc stop <name>  Stop a workspace (close its tabs)"
      echo "  wkc list         List all workspaces"
      echo "  wkc edit         Open config file in \$EDITOR"
      echo ""
      echo "Config: $WKC_CONFIG"
      ;;
    "")
      # No argument: fzf interactive selection
      if ! command -v fzf &>/dev/null; then
        echo "wkc: fzf not found, please specify a workspace name or install fzf" >&2
        wkc list
        return 1
      fi
      echo "Config: $WKC_CONFIG"
      echo ""
      local selected
      selected=$(_wkc_parse list_detail | column -t -s $'\t' | fzf \
        --prompt="Select workspace: " \
        --height=40% \
        --reverse \
        --header="↑/↓: select | Enter: launch | Esc: exit" | awk '{print $1}')
      if [[ -n "$selected" ]]; then
        _wkc_launch "$selected"
      fi
      ;;
    *)
      if [[ "$1" == "stop" ]]; then
        if [[ -z "$2" ]]; then
          echo "Usage: wkc stop <name>" >&2
          return 1
        fi
        _wkc_stop "$2"
      else
        _wkc_launch "$1"
      fi
      ;;
  esac
}

#--------------------------------------------------------------------#
# Completion                                                         #
#--------------------------------------------------------------------#

_wkc_completion() {
  local -a workspace_names
  workspace_names=(${(f)"$(_wkc_parse list 2>/dev/null)"})
  workspace_names+=(list stop edit help)
  _describe 'workspace' workspace_names
}
compdef _wkc_completion wkc
