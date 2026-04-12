#!/usr/bin/env bash
set -euo pipefail

# Sync wallpapers from dharmx/walls into a local wallpapers folder.
#
# Env vars:
#   WALLS_REPO_URL   (default: https://github.com/dharmx/walls.git)
#   WALLS_DEST       (default: ~/.local/share/wallpapers/Wallpapers)
#   WALLS_WORKDIR    (default: ~/.cache/walls-sync/dharmx-walls)
#   WALLS_FULL       (1=full clone, 0=sparse mode; default: 0)
#   WALLS_CATEGORIES (space-separated dirs in sparse mode; default: abstract)
#   WALLS_PROMPT     (1=prompt in interactive shells, 0=skip prompt; default: 1)
#   WALLS_THUMBNAILS_DIR (default: ~/.cache/wallpaper-picker/thumbnails)
#   WALLS_THUMBNAIL_SIZE (default: 160x90)
#   WALLS_PICKER_MANIFEST (default: ~/.cache/wallpaper-picker/manifest.tsv)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/logging.sh"
setup_logger walls-sync

WALLS_REPO_URL="${WALLS_REPO_URL:-https://github.com/dharmx/walls.git}"
WALLS_DEST="${WALLS_DEST:-$HOME/.local/share/wallpapers/Wallpapers}"
WALLS_WORKDIR="${WALLS_WORKDIR:-$HOME/.cache/walls-sync/dharmx-walls}"
WALLS_FULL="${WALLS_FULL:-0}"
WALLS_CATEGORIES="${WALLS_CATEGORIES:-abstract}"
WALLS_PROMPT="${WALLS_PROMPT:-1}"
WALLS_THUMBNAILS_DIR="${WALLS_THUMBNAILS_DIR:-$HOME/.cache/wallpaper-picker/thumbnails}"
WALLS_THUMBNAIL_SIZE="${WALLS_THUMBNAIL_SIZE:-160x90}"
WALLS_PICKER_MANIFEST="${WALLS_PICKER_MANIFEST:-$HOME/.cache/wallpaper-picker/manifest.tsv}"
SYNC_ACTION=''
EXPORT_ACTION=''
AVAILABLE_CATEGORIES=(
  abstract
  aerial
  animated
  anime
  apeiros
  apocalypse
  architecture
  basalt
  boccha
  calm
  centered
  cherry
  chillop
  cold
  decay
  devicons
  digital
  dreamcore
  evangelion
  fauna
  flowers
  fogsmoke
  geometry
  girl
  gruvbox
  halloween
  industrial
  interior
  jackb
  lightbulb
  logo
  m-26.jp
  manga
  minimal
  monochrome
  mountain
  nature
  nord
  outrun
  painting
  paper
  pixel
  poly
  radium
  retro
  solarized
  spam
  stalenhag
  tile
  unsorted
  wave
  weirdcore
)

ensure_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    log_error "missing command: $1"
    exit 1
  }
}

join_by() {
  local separator="$1"
  shift
  local first=1
  local item
  for item in "$@"; do
    if (( first )); then
      printf '%s' "$item"
      first=0
    else
      printf '%s%s' "$separator" "$item"
    fi
  done
}

append_unique() {
  local candidate="$1"
  shift
  local existing
  for existing in "$@"; do
    [[ "$existing" == "$candidate" ]] && return 0
  done
  return 1
}

is_known_category() {
  local wanted="$1"
  local category
  for category in "${AVAILABLE_CATEGORIES[@]}"; do
    [[ "$category" == "$wanted" ]] && return 0
  done
  return 1
}

resolve_category_token() {
  local token="$1"
  local start end index

  if [[ "$token" =~ ^[0-9]+$ ]]; then
    if (( token < 1 || token > ${#AVAILABLE_CATEGORIES[@]} )); then
      log_error "invalid category number: $token"
      exit 1
    fi
    printf '%s\n' "${AVAILABLE_CATEGORIES[token-1]}"
    return 0
  fi

  if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
    start="${BASH_REMATCH[1]}"
    end="${BASH_REMATCH[2]}"
    if (( start < 1 || end < 1 || start > ${#AVAILABLE_CATEGORIES[@]} || end > ${#AVAILABLE_CATEGORIES[@]} || start > end )); then
      log_error "invalid category range: $token"
      exit 1
    fi
    for ((index = start; index <= end; index++)); do
      printf '%s\n' "${AVAILABLE_CATEGORIES[index-1]}"
    done
    return 0
  fi

  if ! is_known_category "$token"; then
    log_error "unknown wallpaper category: $token"
    exit 1
  fi

  printf '%s\n' "$token"
}

parse_category_selection() {
  local raw="$1"
  local normalized token resolved
  local -a selected=()

  normalized="${raw//,/ }"
  for token in $normalized; do
    while IFS= read -r resolved; do
      append_unique "$resolved" "${selected[@]}" || selected+=("$resolved")
    done < <(resolve_category_token "$token")
  done

  if (( ${#selected[@]} == 0 )); then
    selected=(abstract)
  fi

  WALLS_CATEGORIES="$(join_by ' ' "${selected[@]}")"
}

validate_categories() {
  local raw="$1"
  local category
  for category in $raw; do
    if ! is_known_category "$category"; then
      log_error "unknown wallpaper category: $category"
      log "available categories: $(join_by ', ' "${AVAILABLE_CATEGORIES[@]}")"
      exit 1
    fi
  done
}

select_categories_interactively() {
  local choice raw

  printf '\nWallpaper sync options:\n'
  printf '  1. Default category (abstract)\n'
  printf '  2. Choose one or more categories\n'
  printf '  3. Download all categories\n'
  printf 'Selection [1]: '
  read -r choice || choice='1'
  choice="${choice:-1}"

  case "$choice" in
    1)
      WALLS_FULL='0'
      WALLS_CATEGORIES='abstract'
      ;;
    2)
      printf '\nAvailable categories:\n'
      local i=1
      local category
      for category in "${AVAILABLE_CATEGORIES[@]}"; do
        printf '  %2d. %s\n' "$i" "$category"
        ((i++))
      done
      printf '\nSelect multiple folders with names, numbers, commas, spaces, or ranges.\n'
      printf 'Examples: `abstract nature`, `1 7 12`, `1-3,8,10-12`\n'
      printf 'Your selection [abstract]: '
      read -r raw || raw='abstract'
      raw="${raw:-abstract}"
      WALLS_FULL='0'
      parse_category_selection "$raw"
      ;;
    3)
      WALLS_FULL='1'
      WALLS_CATEGORIES=''
      ;;
    *)
      log_error "invalid selection: $choice"
      exit 1
      ;;
  esac
}

configure_sync_scope() {
  if [[ "$WALLS_PROMPT" != '1' || ! -t 0 ]]; then
    validate_categories "$WALLS_CATEGORIES"
    return 0
  fi

  if [[ "${WALLS_FULL}" == '1' ]]; then
    return 0
  fi

  if [[ "${WALLS_CATEGORIES}" != 'abstract' ]]; then
    validate_categories "$WALLS_CATEGORIES"
    return 0
  fi

  select_categories_interactively

  if [[ "$WALLS_FULL" != '1' ]]; then
    validate_categories "$WALLS_CATEGORIES"
  fi
}

setup_sparse_checkout() {
  log "configuring sparse checkout categories: ${WALLS_CATEGORIES}"
  git -C "$WALLS_WORKDIR" sparse-checkout init --cone
  # shellcheck disable=SC2086
  git -C "$WALLS_WORKDIR" sparse-checkout set $WALLS_CATEGORIES
}

clone_repo() {
  mkdir -p "$(dirname "$WALLS_WORKDIR")"
  if [[ -d "$WALLS_WORKDIR" && ! -d "$WALLS_WORKDIR/.git" ]]; then
    rm -rf "$WALLS_WORKDIR"
  fi

  if [[ "$WALLS_FULL" == '1' ]]; then
    log 'cloning full wallpaper repository (this can be very large)'
    git clone "$WALLS_REPO_URL" "$WALLS_WORKDIR"
    SYNC_ACTION='cloned full repository'
    return 0
  fi

  log 'cloning wallpaper repository in sparse mode'
  git clone --filter=blob:none --no-checkout "$WALLS_REPO_URL" "$WALLS_WORKDIR"
  setup_sparse_checkout
  git -C "$WALLS_WORKDIR" checkout main || git -C "$WALLS_WORKDIR" checkout master
  SYNC_ACTION="cloned sparse repository (${WALLS_CATEGORIES})"
}

update_repo() {
  if [[ "$WALLS_FULL" == '1' ]]; then
    log 'updating full wallpaper repository'
    git -C "$WALLS_WORKDIR" sparse-checkout disable >/dev/null 2>&1 || true
    git -C "$WALLS_WORKDIR" pull --ff-only
    SYNC_ACTION='updated full repository'
    return 0
  fi

  setup_sparse_checkout
  log 'updating sparse wallpaper repository'
  git -C "$WALLS_WORKDIR" pull --ff-only
  SYNC_ACTION="updated sparse repository (${WALLS_CATEGORIES})"
}

export_snapshot() {
  mkdir -p "$WALLS_DEST"

  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete --exclude '.git' "$WALLS_WORKDIR"/ "$WALLS_DEST"/
  else
    log_warn 'rsync not found; copying files without cleanup'
    cp -a "$WALLS_WORKDIR"/. "$WALLS_DEST"/
  fi

  rm -rf "$WALLS_DEST/.git"
  EXPORT_ACTION="$WALLS_WORKDIR -> $WALLS_DEST"
}

is_supported_image() {
  local file="$1"
  case "${file,,}" in
    *.jpg|*.jpeg|*.png|*.webp|*.bmp|*.gif|*.tif|*.tiff|*.svg)
      return 0
      ;;
  esac
  return 1
}

thumbnail_name_for() {
  local image="$1"
  local stat_data
  stat_data="$(stat -Lc '%n:%Y:%s' "$image" 2>/dev/null || stat -f '%N:%m:%z' "$image")"
  printf '%s' "$stat_data" | sha256sum | cut -d' ' -f1
}

generate_thumbnails() {
  local -a candidates=()
  local image thumbnail generated_count=0 reused_count=0

  if ! command -v magick >/dev/null 2>&1; then
    log_warn 'ImageMagick not found; skipping wallpaper thumbnail generation'
    return 0
  fi

  log "generating wallpaper thumbnails in: $WALLS_THUMBNAILS_DIR"
  mkdir -p "$WALLS_THUMBNAILS_DIR"

  if command -v fd >/dev/null 2>&1 && command -v sort >/dev/null 2>&1; then
    mapfile -d '' -t candidates < <(fd -HI -t f -0 . "$WALLS_DEST" | sort -z)
  elif command -v fd >/dev/null 2>&1; then
    mapfile -d '' -t candidates < <(fd -HI -t f -0 . "$WALLS_DEST")
  elif command -v sort >/dev/null 2>&1; then
    mapfile -d '' -t candidates < <(find "$WALLS_DEST" -type f -print0 | sort -z)
  else
    mapfile -d '' -t candidates < <(find "$WALLS_DEST" -type f -print0)
  fi

  for image in "${candidates[@]}"; do
    is_supported_image "$image" || continue
    thumbnail="$WALLS_THUMBNAILS_DIR/$(thumbnail_name_for "$image").png"
    if [[ -f "$thumbnail" ]]; then
      ((reused_count += 1))
      continue
    fi
    if magick "$image" \
      -auto-orient \
      -thumbnail "${WALLS_THUMBNAIL_SIZE}^" \
      -gravity center \
      -extent "$WALLS_THUMBNAIL_SIZE" \
      PNG:"$thumbnail" >/dev/null 2>&1; then
      ((generated_count += 1))
    fi
  done

  log "thumbnail summary: generated=$generated_count reused=$reused_count"
}

generate_picker_manifest() {
  local -a candidates=()
  local cache_dir tmp_manifest image rel dir file label thumbnail icon_path entry_count=0

  cache_dir="$(dirname "$WALLS_PICKER_MANIFEST")"
  mkdir -p "$cache_dir"
  tmp_manifest="$(mktemp "$cache_dir/manifest.tsv.XXXXXX")"

  log "writing wallpaper picker manifest: $WALLS_PICKER_MANIFEST"

  if command -v fd >/dev/null 2>&1 && command -v sort >/dev/null 2>&1; then
    mapfile -d '' -t candidates < <(fd -HI -t f -0 . "$WALLS_DEST" | sort -z)
  elif command -v fd >/dev/null 2>&1; then
    mapfile -d '' -t candidates < <(fd -HI -t f -0 . "$WALLS_DEST")
  elif command -v sort >/dev/null 2>&1; then
    mapfile -d '' -t candidates < <(find "$WALLS_DEST" -type f -print0 | sort -z)
  else
    mapfile -d '' -t candidates < <(find "$WALLS_DEST" -type f -print0)
  fi

  : > "$tmp_manifest"
  for image in "${candidates[@]}"; do
    is_supported_image "$image" || continue
    rel="${image#"$WALLS_DEST/"}"
    file="${rel##*/}"
    dir="${rel%/*}"
    [[ "$dir" == "$rel" ]] && dir='.'
    label="$dir - $file"
    thumbnail="$WALLS_THUMBNAILS_DIR/$(thumbnail_name_for "$image").png"
    icon_path="$image"
    [[ -f "$thumbnail" ]] && icon_path="$thumbnail"
    printf '%s\t%s\t%s\n' "$label" "$image" "$icon_path" >> "$tmp_manifest"
    ((entry_count += 1))
  done

  mv "$tmp_manifest" "$WALLS_PICKER_MANIFEST"
  log "picker manifest entries: $entry_count"
}

main() {
  ensure_cmd git
  configure_sync_scope

  if [[ -d "$WALLS_WORKDIR/.git" ]]; then
    update_repo
  else
    clone_repo
  fi

  export_snapshot
  generate_thumbnails
  generate_picker_manifest
  log 'summary:'
  log "sync action: $SYNC_ACTION"
  log "exported wallpapers: $EXPORT_ACTION"
  log_success "done; wallpapers available under: $WALLS_DEST"
  log 'tip: run ~/.config/scripts/wallpaper_picker.sh to search/apply a wallpaper with Wofi'
}

main "$@"
