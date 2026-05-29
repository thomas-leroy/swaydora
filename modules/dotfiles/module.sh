#!/usr/bin/env bash
set -euo pipefail

DOTFILES_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_REPO_ROOT="$(cd "$DOTFILES_MODULE_DIR/../.." && pwd)"
DOTFILES_MANAGED_FILE="$DOTFILES_MODULE_DIR/managed.conf"
DOTFILES_SOURCE_ROOT="$DOTFILES_REPO_ROOT/dotfiles"

# shellcheck source=../../lib/backup.sh
source "$DOTFILES_REPO_ROOT/lib/backup.sh"
# shellcheck source=../../lib/path.sh
source "$DOTFILES_REPO_ROOT/lib/path.sh"

dotfiles_display_target() {
  local path="$1"

  path_display_home "$path"
}

dotfiles_display_source() {
  local path="$1"

  printf 'dotfiles/%s\n' "${path#"$DOTFILES_SOURCE_ROOT/"}"
}

dotfiles_each_entry() {
  local callback="$1"
  local line source_name target_name extra
  shift

  [[ -f "$DOTFILES_MANAGED_FILE" ]] || {
    log_error "Managed dotfiles config not found: $DOTFILES_MANAGED_FILE"
    return 1
  }

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "${line:0:1}" == '#' ]] && continue
    IFS=':' read -r source_name target_name extra <<<"$line"
    if [[ -z "${source_name:-}" || -z "${target_name:-}" || -n "${extra:-}" ]]; then
      log_error "Invalid managed dotfiles entry: $line"
      return 1
    fi
    "$callback" "$source_name" "$target_name" "$@"
  done <"$DOTFILES_MANAGED_FILE"
}

dotfiles_validate_relative() {
  local value="$1"

  case "$value" in
    ''|/*|../*|*/../*|*/..|'.'|'..')
      return 1
      ;;
  esac
}

dotfiles_target_path() {
  local target_name="$1"

  printf '%s/.config/%s\n' "$HOME" "$target_name"
}

dotfiles_target_is_safe() {
  local target_path="$1"
  local config_root="$HOME/.config"

  path_under_dir "$target_path" "$config_root"
}

dotfiles_parent_can_exist() {
  local parent="$1"

  while [[ ! -e "$parent" ]]; do
    parent="$(dirname "$parent")"
  done

  [[ -d "$parent" ]]
}

dotfiles_target_state() {
  local target_path="$1"
  local source_path="$2"
  local link_target

  if [[ -L "$target_path" && ! -e "$target_path" ]]; then
    printf 'broken-symlink\n'
  elif [[ -L "$target_path" ]]; then
    link_target="$(readlink "$target_path")"
    if [[ "$link_target" == "$source_path" ]]; then
      printf 'expected-symlink\n'
    else
      printf 'unexpected-symlink\n'
    fi
  elif [[ -f "$target_path" ]]; then
    printf 'file\n'
  elif [[ -d "$target_path" ]]; then
    printf 'directory\n'
  elif [[ -e "$target_path" ]]; then
    printf 'unsupported\n'
  else
    printf 'missing\n'
  fi
}

dotfiles_needs_backup() {
  local state="$1"

  case "$state" in
    file|directory|broken-symlink|unexpected-symlink)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

dotfiles_preflight_one() {
  local source_name="$1"
  local target_name="$2"
  local source_path="$DOTFILES_SOURCE_ROOT/$source_name"
  local target_path parent_path

  if ! dotfiles_validate_relative "$source_name"; then
    log_error "Invalid dotfiles source path: $source_name"
    return 1
  fi

  if ! dotfiles_validate_relative "$target_name"; then
    log_error "Invalid dotfiles target path: $target_name"
    return 1
  fi

  if [[ -e "$source_path" || -L "$source_path" ]]; then
    :
  else
    log_error "Missing source: $(dotfiles_display_source "$source_path")"
    return 1
  fi

  target_path="$(dotfiles_target_path "$target_name")"
  if ! dotfiles_target_is_safe "$target_path"; then
    log_error "Refusing unsafe dotfiles target: $target_path"
    return 1
  fi

  parent_path="$(dirname "$target_path")"
  if ! dotfiles_parent_can_exist "$parent_path"; then
    log_error "Target parent cannot be created: $(dotfiles_display_target "$parent_path")"
    return 1
  fi
}

dotfiles_check_one() {
  local source_name="$1"
  local target_name="$2"

  dotfiles_preflight_one "$source_name" "$target_name" || return 1
  log_ok "Source exists: dotfiles/$source_name -> ~/.config/$target_name"
}

dotfiles_plan_one() {
  local source_name="$1"
  local target_name="$2"
  local source_path="$DOTFILES_SOURCE_ROOT/$source_name"
  local target_path state display_target

  target_path="$(dotfiles_target_path "$target_name")"
  display_target="$(dotfiles_display_target "$target_path")"

  if [[ ! -e "$source_path" && ! -L "$source_path" ]]; then
    log_error "Missing source: $(dotfiles_display_source "$source_path")"
    return 1
  fi

  state="$(dotfiles_target_state "$target_path" "$source_path")"
  case "$state" in
    expected-symlink)
      log_ok "Already linked: $display_target -> $(dotfiles_display_source "$source_path")"
      ;;
    missing)
      log_plan "Would link missing target: $display_target -> $(dotfiles_display_source "$source_path")"
      ;;
    file)
      log_plan "Would backup and replace existing file: $display_target"
      ;;
    directory)
      log_plan "Would backup and replace existing directory: $display_target"
      ;;
    broken-symlink)
      log_plan "Would backup and replace broken symlink: $display_target"
      ;;
    unexpected-symlink)
      log_plan "Would backup and replace unexpected symlink: $display_target"
      ;;
    *)
      log_error "Unsupported target type: $display_target"
      return 1
      ;;
  esac
}

dotfiles_apply_supported() {
  return 0
}

dotfiles_apply_one() {
  local source_name="$1"
  local target_name="$2"
  local batch="$3"
  local source_path="$DOTFILES_SOURCE_ROOT/$source_name"
  local target_path state parent_path display_target saved_path

  target_path="$(dotfiles_target_path "$target_name")"
  state="$(dotfiles_target_state "$target_path" "$source_path")"
  display_target="$(dotfiles_display_target "$target_path")"

  case "$state" in
    expected-symlink)
      log_ok "Already linked: $display_target"
      return 0
      ;;
    missing)
      parent_path="$(dirname "$target_path")"
      mkdir -p "$parent_path"
      ln -s -- "$source_path" "$target_path"
      log_ok "Linked: $display_target -> $(dotfiles_display_source "$source_path")"
      return 0
      ;;
  esac

  if ! dotfiles_needs_backup "$state"; then
    log_error "Unsupported target type: $display_target"
    return 1
  fi

  if [[ -z "$batch" ]]; then
    log_error "Backup batch is required before replacing: $display_target"
    return 1
  fi

  saved_path="$(backup_path_for "$batch" "$target_path")" || return 1
  if [[ ! -e "$saved_path" && ! -L "$saved_path" ]]; then
    log_error "Backup is missing for: $display_target"
    return 1
  fi

  rm -rf -- "$target_path"
  parent_path="$(dirname "$target_path")"
  mkdir -p "$parent_path"
  ln -s -- "$source_path" "$target_path"
  log_ok "Backed up and linked: $display_target"
}

dotfiles_backup_one() {
  local source_name="$1"
  local target_name="$2"
  local batch="$3"
  local source_path="$DOTFILES_SOURCE_ROOT/$source_name"
  local target_path state display_target

  target_path="$(dotfiles_target_path "$target_name")"
  state="$(dotfiles_target_state "$target_path" "$source_path")"
  display_target="$(dotfiles_display_target "$target_path")"

  if dotfiles_needs_backup "$state"; then
    backup_copy_path "$batch" "$target_path" || {
      log_error "Backup failed for: $display_target"
      return 1
    }
  fi
}

dotfiles_preflight() {
  log_info 'Preflighting managed dotfiles'
  dotfiles_each_entry dotfiles_preflight_one
}

dotfiles_backup_required() {
  local line source_name target_name extra
  local source_path target_path state

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "${line:0:1}" == '#' ]] && continue
    IFS=':' read -r source_name target_name extra <<<"$line"
    source_path="$DOTFILES_SOURCE_ROOT/$source_name"
    target_path="$(dotfiles_target_path "$target_name")"
    state="$(dotfiles_target_state "$target_path" "$source_path")"
    if dotfiles_needs_backup "$state"; then
      return 0
    fi
  done <"$DOTFILES_MANAGED_FILE"

  return 1
}

dotfiles_apply_with_optional_backup() {
  local batch=''

  if dotfiles_backup_required; then
    batch="$(backup_create_batch)" || return 1
    log_info "Created backup batch: $batch"
    dotfiles_each_entry dotfiles_backup_one "$batch"
  fi

  dotfiles_each_entry dotfiles_apply_one "$batch"
}

dotfiles_check() {
  log_info 'Checking managed dotfiles sources'
  dotfiles_each_entry dotfiles_check_one
}

dotfiles_plan() {
  log_info 'Planning managed dotfiles links'
  dotfiles_each_entry dotfiles_plan_one
}

dotfiles_apply() {
  log_info 'Applying managed dotfiles links'
  dotfiles_preflight
  dotfiles_apply_with_optional_backup
}
