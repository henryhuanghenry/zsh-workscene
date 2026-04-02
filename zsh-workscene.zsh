# zsh-workscene — work scene manager for iTerm2
# https://github.com/henryhuanghenry/zsh-workscene
# v0.2.0
# Copyright (c) 2026 henryhuanghenry
# MIT License — see LICENSE file for details.

WKC_CONFIG="${WKC_CONFIG:-$HOME/.zsh-workscene.yaml}"

#--------------------------------------------------------------------#
# YAML Config Parser (Python)                                        #
#--------------------------------------------------------------------#

_wkc_parse() {
  python3 -c "
import yaml, json, sys, os

config_path = os.path.expanduser('$WKC_CONFIG')
if not os.path.exists(config_path):
    print('ERROR: config not found: ' + config_path, file=sys.stderr)
    sys.exit(1)

with open(config_path) as f:
    data = yaml.safe_load(f)

workspaces = data.get('workspaces', {})
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
    if name not in workspaces:
        print('ERROR: workspace not found: ' + name, file=sys.stderr)
        sys.exit(1)
    print(json.dumps(workspaces[name]))
" "$@"
}

#--------------------------------------------------------------------#
# iTerm2 Tab Management (AppleScript)                                #
#--------------------------------------------------------------------#

_wkc_open_tab() {
  local dir="$1"
  local cmd="$2"
  local tab_name="$3"

  # Expand ~
  dir="${dir/#\~/$HOME}"

  local script="cd ${dir}"
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

  # Expand ~
  dir="${dir/#\~/$HOME}"

  local script="cd ${dir}"
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
# Editor Launcher                                                    #
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

    _wkc_open_tab "$tab_dir" "$tab_cmd" "$tab_name"
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

      _wkc_split_pane "$pane_direction" "$pane_dir" "$pane_cmd"
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
      echo "Usage: wkc [name|list|edit]"
      echo ""
      echo "  wkc           Interactive selection (requires fzf)"
      echo "  wkc <name>    Launch a workspace"
      echo "  wkc list      List all workspaces"
      echo "  wkc edit      Open config file in \$EDITOR"
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
      _wkc_launch "$1"
      ;;
  esac
}

#--------------------------------------------------------------------#
# Completion                                                         #
#--------------------------------------------------------------------#

_wkc_completion() {
  local -a workspace_names
  workspace_names=(${(f)"$(_wkc_parse list 2>/dev/null)"})
  workspace_names+=(list edit help)
  _describe 'workspace' workspace_names
}
compdef _wkc_completion wkc
