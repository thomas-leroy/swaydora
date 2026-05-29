#!/usr/bin/env bash
set -euo pipefail

BACKUP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=log.sh
source "$BACKUP_LIB_DIR/log.sh"
# shellcheck source=path.sh
source "$BACKUP_LIB_DIR/path.sh"

backup_root() {
  printf '%s/.local/share/swaydora/backups\n' "$HOME"
}

backup_create_batch() {
  local root batch created_at suffix

  root="$(backup_root)"
  created_at="$(date '+%Y%m%d-%H%M%S')"
  suffix=0

  while :; do
    if [[ "$suffix" -eq 0 ]]; then
      batch="$root/$created_at"
    else
      batch="$(printf '%s/%s-%02d' "$root" "$created_at" "$suffix")"
    fi

    [[ -e "$batch" ]] || break
    suffix=$((suffix + 1))
  done

  mkdir -p "$batch/files"
  : > "$batch/manifest.tsv"
  printf '%s\n' "$batch"
}

backup_validate_batch() {
  local batch="$1"
  local root

  root="$(backup_root)"
  case "$batch" in
    "$root"/*)
      ;;
    *)
      log_error "Backup batch is outside backup root: $batch"
      return 1
      ;;
  esac
}

backup_path_for() {
  local batch="$1"
  local original_path="$2"
  local relative_path

  backup_validate_batch "$batch" || return 1

  case "$original_path" in
    /*)
      ;;
    *)
      log_error "Backup source must be an absolute path: $original_path"
      return 1
      ;;
  esac

  relative_path="${original_path#/}"
  printf '%s/files/%s\n' "$batch" "$relative_path"
}

backup_validate_manifest_value() {
  local value="$1"

  if [[ "$value" == *$'\t'* || "$value" == *$'\n'* ]]; then
    log_error 'Backup manifest values must not contain tabs or newlines'
    return 1
  fi
}

backup_record_manifest_entry() {
  local batch="$1"
  local original_path="$2"
  local backup_path="$3"
  local path_type="$4"
  local created_at

  backup_validate_batch "$batch" || return 1
  backup_validate_manifest_value "$original_path" || return 1
  backup_validate_manifest_value "$backup_path" || return 1
  backup_validate_manifest_value "$path_type" || return 1

  created_at="$(date '+%Y-%m-%dT%H:%M:%S%z')"
  printf '%s\t%s\t%s\t%s\n' \
    "$original_path" \
    "$backup_path" \
    "$path_type" \
    "$created_at" >> "$batch/manifest.tsv"
}

backup_path_type() {
  local path="$1"

  if [[ -L "$path" ]]; then
    printf 'symlink\n'
  elif [[ -f "$path" ]]; then
    printf 'file\n'
  elif [[ -d "$path" ]]; then
    printf 'directory\n'
  else
    log_error "Unsupported backup path type: $path"
    return 1
  fi
}

backup_copy_path() {
  local batch="$1"
  local original_path="$2"
  local backup_path path_type backup_parent

  if [[ ! -e "$original_path" && ! -L "$original_path" ]]; then
    log_warn "Backup source does not exist, skipping: $original_path"
    return 0
  fi

  path_type="$(backup_path_type "$original_path")" || return 1
  backup_path="$(backup_path_for "$batch" "$original_path")" || return 1
  backup_parent="$(dirname "$backup_path")"

  if [[ -e "$backup_path" || -L "$backup_path" ]]; then
    log_error "Backup destination already exists: $backup_path"
    return 1
  fi

  mkdir -p "$backup_parent"
  cp -a -- "$original_path" "$backup_path"
  backup_record_manifest_entry "$batch" "$original_path" "$backup_path" "$path_type"
}

backup_latest_batch() {
  local root latest

  root="$(backup_root)"
  if [[ ! -d "$root" ]]; then
    return 1
  fi

  latest="$(
    find "$root" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
      | sort \
      | tail -n 1
  )"
  [[ -n "$latest" ]] || return 1
  printf '%s/%s\n' "$root" "$latest"
}

backup_path_under() {
  local path="$1"
  local root="$2"

  path_under_dir "$path" "$root"
}

backup_validate_manifest_entry() {
  local batch="$1"
  local original_path="$2"
  local backup_path="$3"
  local path_type="$4"
  local created_at="$5"
  local config_root="$HOME/.config"

  backup_validate_batch "$batch" || return 1

  if ! backup_path_under "$original_path" "$config_root"; then
    log_error "Manifest original path is outside ~/.config: $original_path"
    return 1
  fi

  if ! backup_path_under "$backup_path" "$batch/files"; then
    log_error "Manifest backup path is outside selected batch: $backup_path"
    return 1
  fi

  if [[ ! -e "$backup_path" && ! -L "$backup_path" ]]; then
    log_error "Manifest backup path is missing: $backup_path"
    return 1
  fi

  case "$path_type" in
    file)
      [[ -f "$backup_path" && ! -L "$backup_path" ]] || {
        log_error "Manifest expected file backup: $backup_path"
        return 1
      }
      ;;
    directory)
      [[ -d "$backup_path" && ! -L "$backup_path" ]] || {
        log_error "Manifest expected directory backup: $backup_path"
        return 1
      }
      ;;
    symlink)
      [[ -L "$backup_path" ]] || {
        log_error "Manifest expected symlink backup: $backup_path"
        return 1
      }
      ;;
    *)
      log_error "Unsupported manifest path type: $path_type"
      return 1
      ;;
  esac

  [[ -n "$created_at" ]] || {
    log_error "Manifest created_at is empty for: $original_path"
    return 1
  }
}

backup_read_manifest() {
  local batch="$1"
  local callback="$2"
  local manifest line original_path backup_path path_type created_at extra
  shift 2

  manifest="$batch/manifest.tsv"
  [[ -f "$manifest" ]] || {
    log_error "Backup manifest not found: $manifest"
    return 1
  }

  while IFS= read -r line || [[ -n "$line" ]]; do
    IFS=$'\t' read -r original_path backup_path path_type created_at extra <<<"$line"
    if [[ -z "${original_path:-}" || -z "${backup_path:-}" || -z "${path_type:-}" || -z "${created_at:-}" || -n "${extra:-}" ]]; then
      log_error "Malformed manifest entry: $line"
      return 1
    fi
    backup_validate_manifest_entry "$batch" "$original_path" "$backup_path" "$path_type" "$created_at" || return 1
    "$callback" "$original_path" "$backup_path" "$path_type" "$created_at" "$@"
  done <"$manifest"
}

backup_restore_batch_plan_one() {
  local original_path="$1"
  local backup_path="$2"
  local path_type="$3"

  log_plan "Would restore $path_type: $original_path <- $backup_path"
}

backup_restore_batch_plan() {
  local batch="$1"

  backup_read_manifest "$batch" backup_restore_batch_plan_one
}

backup_restore_current_one() {
  local original_path="$1"
  local backup_path="$2"
  local path_type="$3"
  local created_at="$4"
  local pre_batch="$5"

  if [[ -e "$original_path" || -L "$original_path" ]]; then
    backup_copy_path "$pre_batch" "$original_path" || return 1
  fi
}

backup_restore_copy_one() {
  local original_path="$1"
  local backup_path="$2"
  local path_type="$3"
  local created_at="$4"
  local parent_path

  parent_path="$(dirname "$original_path")"
  mkdir -p "$parent_path"
  rm -rf -- "$original_path"
  cp -a -- "$backup_path" "$original_path"
}

backup_restore_batch_apply() {
  local batch="$1"
  local pre_batch

  backup_read_manifest "$batch" backup_restore_batch_plan_one >/dev/null || return 1

  pre_batch="$(backup_create_batch)" || return 1
  backup_read_manifest "$batch" backup_restore_current_one "$pre_batch" || return 1
  backup_read_manifest "$batch" backup_restore_copy_one
  printf '%s\n' "$pre_batch"
}
