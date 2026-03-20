#!/usr/bin/env bash
# Sync toolkit skills, agents, and CLAUDE.md from configured git sources.
# Usage: sync-toolkit.sh <pull|status|drift>
#
# Reads configuration from ~/.claude/toolkit.yaml
# Requires: git, python3 (for YAML parsing)

set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
CONFIG="$CLAUDE_DIR/toolkit.yaml"
COMMAND="${1:-}"

# --- helpers ---

die() { echo "ERROR: $*" >&2; exit 1; }

require_config() {
    if [ ! -f "$CONFIG" ]; then
        die "No toolkit.yaml found at $CONFIG. Run install.sh or create one manually."
    fi
}

# Parse toolkit.yaml using python3 (avoids yq dependency)
parse_yaml() {
    python3 -c "
import yaml, json, sys

with open('$CONFIG') as f:
    config = yaml.safe_load(f)

json.dump(config, sys.stdout)
" 2>/dev/null || python3 -c "
# Fallback: minimal YAML parsing without PyYAML
import json, sys, re

config = {'sources': [], 'targets': {}, 'cache_dir': '$CLAUDE_DIR/toolkit-cache'}
current_source = None

with open('$CONFIG') as f:
    for line in f:
        line = line.rstrip()
        stripped = line.lstrip()

        # Skip comments and empty lines
        if not stripped or stripped.startswith('#'):
            continue

        # Detect source list items
        if stripped.startswith('- name:'):
            current_source = {'name': stripped.split(':', 1)[1].strip(), 'install': {}}
            config['sources'].append(current_source)
        elif current_source is not None:
            if stripped.startswith('repo:'):
                current_source['repo'] = stripped.split(':', 1)[1].strip()
            elif stripped.startswith('branch:'):
                current_source['branch'] = stripped.split(':', 1)[1].strip()
            elif stripped.startswith('skills:'):
                current_source['install']['skills'] = stripped.split(':', 1)[1].strip()
            elif stripped.startswith('agents:'):
                current_source['install']['agents'] = stripped.split(':', 1)[1].strip()
            elif stripped.startswith('claude-md:'):
                current_source['install']['claude-md'] = stripped.split(':', 1)[1].strip()

        # Targets section
        if re.match(r'^targets:', line):
            current_source = None
        if current_source is None:
            if stripped.startswith('skills:') and 'targets' in line or (len(config['sources']) > 0 and '~/' in stripped):
                pass  # handled by specific checks below

        # Simple top-level targets
        if line.startswith('  skills:') and current_source is None:
            config['targets']['skills'] = stripped.split(':', 1)[1].strip()
        elif line.startswith('  agents:') and current_source is None:
            config['targets']['agents'] = stripped.split(':', 1)[1].strip()
        elif line.startswith('  claude-md:') and current_source is None:
            config['targets']['claude-md'] = stripped.split(':', 1)[1].strip()
        elif stripped.startswith('cache_dir:'):
            config['cache_dir'] = stripped.split(':', 1)[1].strip()

json.dump(config, sys.stdout)
"
}

# Expand ~ in paths
expand_path() {
    echo "${1/#\~/$HOME}"
}

# --- commands ---

cmd_pull() {
    require_config
    local config_json
    config_json=$(parse_yaml)

    local cache_dir
    cache_dir=$(expand_path "$(echo "$config_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('cache_dir','$CLAUDE_DIR/toolkit-cache'))")")
    mkdir -p "$cache_dir"

    local target_skills target_agents target_claude_md
    target_skills=$(expand_path "$(echo "$config_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('targets',{}).get('skills','$CLAUDE_DIR/skills'))")")
    target_agents=$(expand_path "$(echo "$config_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('targets',{}).get('agents','$CLAUDE_DIR/agents'))")")
    target_claude_md=$(expand_path "$(echo "$config_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('targets',{}).get('claude-md','$CLAUDE_DIR/CLAUDE.md'))")")

    local num_sources
    num_sources=$(echo "$config_json" | python3 -c "import json,sys; print(len(json.load(sys.stdin).get('sources',[])))")

    if [ "$num_sources" -eq 0 ]; then
        die "No sources configured in $CONFIG"
    fi

    echo "Syncing from $num_sources source(s)..."
    echo ""

    for i in $(seq 0 $((num_sources - 1))); do
        local name repo branch
        name=$(echo "$config_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['sources'][$i]['name'])")
        repo=$(echo "$config_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['sources'][$i]['repo'])")
        branch=$(echo "$config_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['sources'][$i].get('branch','main'))")

        local repo_cache="$cache_dir/$name"

        echo "--- Source: $name ($repo) ---"

        # Clone or pull
        if [ -d "$repo_cache/.git" ]; then
            echo "  Pulling latest..."
            git -C "$repo_cache" fetch origin "$branch" --quiet
            git -C "$repo_cache" checkout "$branch" --quiet 2>/dev/null || true
            git -C "$repo_cache" reset --hard "origin/$branch" --quiet
        else
            echo "  Cloning..."
            git clone --branch "$branch" --single-branch --quiet "$repo" "$repo_cache"
        fi

        # Copy skills
        local install_skills
        install_skills=$(echo "$config_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['sources'][$i].get('install',{}).get('skills',''))" 2>/dev/null)
        if [ -n "$install_skills" ]; then
            local src="$repo_cache/$install_skills"
            if [ -d "$src" ]; then
                mkdir -p "$target_skills"
                # Remove target symlink if it exists (migrating from symlink install)
                if [ -L "$target_skills" ]; then
                    echo "  Warning: $target_skills is a symlink. Skipping copy."
                    echo "  Remove the symlink first to use sync-toolkit."
                else
                    local count=0
                    for skill_dir in "$src"/*/; do
                        [ -d "$skill_dir" ] || continue
                        local skill_name
                        skill_name=$(basename "$skill_dir")
                        cp -r "$skill_dir" "$target_skills/$skill_name"
                        count=$((count + 1))
                    done
                    echo "  Skills: copied $count skill(s)"
                fi
            fi
        fi

        # Copy agents
        local install_agents
        install_agents=$(echo "$config_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['sources'][$i].get('install',{}).get('agents',''))" 2>/dev/null)
        if [ -n "$install_agents" ]; then
            local src="$repo_cache/$install_agents"
            if [ -d "$src" ]; then
                mkdir -p "$target_agents"
                if [ -L "$target_agents" ]; then
                    echo "  Warning: $target_agents is a symlink. Skipping copy."
                else
                    local count=0
                    for agent_file in "$src"/*.md; do
                        [ -f "$agent_file" ] || continue
                        cp "$agent_file" "$target_agents/"
                        count=$((count + 1))
                    done
                    echo "  Agents: copied $count agent(s)"
                fi
            fi
        fi

        # Copy CLAUDE.md
        local install_claude_md
        install_claude_md=$(echo "$config_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['sources'][$i].get('install',{}).get('claude-md',''))" 2>/dev/null)
        if [ -n "$install_claude_md" ]; then
            local src="$repo_cache/$install_claude_md"
            if [ -f "$src" ]; then
                if [ -L "$target_claude_md" ]; then
                    echo "  Warning: $target_claude_md is a symlink. Skipping copy."
                else
                    cp "$src" "$target_claude_md"
                    echo "  CLAUDE.md: updated"
                fi
            fi
        fi

        echo ""
    done

    # Record sync timestamp
    date -Iseconds > "$cache_dir/.last-sync"
    echo "Sync complete. Timestamp: $(cat "$cache_dir/.last-sync")"
}

cmd_status() {
    require_config
    local config_json
    config_json=$(parse_yaml)

    local cache_dir
    cache_dir=$(expand_path "$(echo "$config_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('cache_dir','$CLAUDE_DIR/toolkit-cache'))")")

    local num_sources
    num_sources=$(echo "$config_json" | python3 -c "import json,sys; print(len(json.load(sys.stdin).get('sources',[])))")

    echo "=== Toolkit Status ==="
    echo ""
    echo "Config: $CONFIG"
    echo "Cache:  $cache_dir"

    if [ -f "$cache_dir/.last-sync" ]; then
        echo "Last sync: $(cat "$cache_dir/.last-sync")"
    else
        echo "Last sync: never"
    fi

    echo ""
    echo "Sources ($num_sources):"

    for i in $(seq 0 $((num_sources - 1))); do
        local name repo branch
        name=$(echo "$config_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['sources'][$i]['name'])")
        repo=$(echo "$config_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['sources'][$i]['repo'])")
        branch=$(echo "$config_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['sources'][$i].get('branch','main'))")

        local repo_cache="$cache_dir/$name"

        echo ""
        echo "  [$name]"
        echo "    Repo:   $repo"
        echo "    Branch: $branch"

        if [ -d "$repo_cache/.git" ]; then
            local local_head remote_head
            local_head=$(git -C "$repo_cache" rev-parse HEAD 2>/dev/null || echo "unknown")
            git -C "$repo_cache" fetch origin "$branch" --quiet 2>/dev/null || true
            remote_head=$(git -C "$repo_cache" rev-parse "origin/$branch" 2>/dev/null || echo "unknown")

            echo "    Cache:  $repo_cache"
            echo "    Local:  ${local_head:0:8}"
            echo "    Remote: ${remote_head:0:8}"

            if [ "$local_head" = "$remote_head" ]; then
                echo "    Status: up to date"
            else
                echo "    Status: UPDATES AVAILABLE"
            fi
        else
            echo "    Cache:  not cloned"
        fi
    done
}

cmd_drift() {
    require_config
    local config_json
    config_json=$(parse_yaml)

    local cache_dir
    cache_dir=$(expand_path "$(echo "$config_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('cache_dir','$CLAUDE_DIR/toolkit-cache'))")")

    local target_skills
    target_skills=$(expand_path "$(echo "$config_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('targets',{}).get('skills','$CLAUDE_DIR/skills'))")")

    echo "=== Drift Report ==="
    echo ""

    # Check if targets are symlinks
    if [ -L "$target_skills" ]; then
        echo "Skills directory is a symlink → no drift possible (live link to source)."
        echo "  $target_skills → $(readlink -f "$target_skills")"
        return 0
    fi

    if [ ! -d "$cache_dir" ]; then
        echo "No cache directory found. Run /sync-toolkit pull first."
        return 1
    fi

    local num_sources
    num_sources=$(echo "$config_json" | python3 -c "import json,sys; print(len(json.load(sys.stdin).get('sources',[])))")

    local modified=0
    local orphans=0

    for i in $(seq 0 $((num_sources - 1))); do
        local name
        name=$(echo "$config_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['sources'][$i]['name'])")

        local install_skills
        install_skills=$(echo "$config_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['sources'][$i].get('install',{}).get('skills',''))" 2>/dev/null)

        if [ -n "$install_skills" ] && [ -d "$cache_dir/$name/$install_skills" ]; then
            echo "Checking skills from source '$name'..."

            for skill_dir in "$cache_dir/$name/$install_skills"/*/; do
                [ -d "$skill_dir" ] || continue
                local skill_name
                skill_name=$(basename "$skill_dir")
                local installed="$target_skills/$skill_name/SKILL.md"
                local source="$skill_dir/SKILL.md"

                if [ ! -f "$installed" ]; then
                    echo "  MISSING: $skill_name (in source but not installed)"
                elif ! diff -q "$source" "$installed" >/dev/null 2>&1; then
                    echo "  MODIFIED: $skill_name (local differs from source)"
                    modified=$((modified + 1))
                fi
            done
        fi
    done

    # Find orphans (installed but not in any source)
    if [ -d "$target_skills" ]; then
        echo ""
        echo "Checking for orphan skills..."
        for installed_dir in "$target_skills"/*/; do
            [ -d "$installed_dir" ] || continue
            local skill_name
            skill_name=$(basename "$installed_dir")
            local found=false

            for i in $(seq 0 $((num_sources - 1))); do
                local name install_skills
                name=$(echo "$config_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['sources'][$i]['name'])")
                install_skills=$(echo "$config_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['sources'][$i].get('install',{}).get('skills',''))" 2>/dev/null)
                if [ -n "$install_skills" ] && [ -d "$cache_dir/$name/$install_skills/$skill_name" ]; then
                    found=true
                    break
                fi
            done

            if [ "$found" = false ]; then
                echo "  ORPHAN: $skill_name (not in any configured source)"
                orphans=$((orphans + 1))
            fi
        done
    fi

    echo ""
    echo "Summary: $modified modified, $orphans orphan(s)"
}

# --- main ---

case "$COMMAND" in
    pull)   cmd_pull ;;
    status) cmd_status ;;
    drift)  cmd_drift ;;
    "")     die "Usage: sync-toolkit.sh <pull|status|drift>" ;;
    *)      die "Unknown command: $COMMAND. Use: pull, status, drift" ;;
esac
