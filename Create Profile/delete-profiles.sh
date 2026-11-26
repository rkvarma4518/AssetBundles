#!/usr/bin/env bash
# Delete Databricks CLI profiles from ~/.databrickscfg
#
# Usage:
#   ./delete-profiles.sh                      # delete only the clients listed in env.yml
#   ./delete-profiles.sh --all                # delete EVERY profile in ~/.databrickscfg
#   ./delete-profiles.sh --profile clienta    # delete one profile by name
#   ./delete-profiles.sh --env other.yml      # use a different env file
#   ./delete-profiles.sh --yes                # skip the confirmation prompt
#   ./delete-profiles.sh --clear-oauth-cache  # also remove cached OAuth tokens
#
# A backup of the config file is always made before anything is changed.
# Requirements: none besides bash/awk. No yq needed.

set -euo pipefail

ENV_FILE="env.yml"
CFG="${DATABRICKS_CONFIG_FILE:-$HOME/.databrickscfg}"
MODE="env"          # env | all | single
SINGLE=""
ASSUME_YES="false"
CLEAR_CACHE="false"

# ---- args -----------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)               MODE="all"; shift ;;
    --profile)           MODE="single"; SINGLE="${2:?--profile needs a name}"; shift 2 ;;
    --env)               ENV_FILE="${2:?--env needs a file}"; shift 2 ;;
    --yes|-y)            ASSUME_YES="true"; shift ;;
    --clear-oauth-cache) CLEAR_CACHE="true"; shift ;;
    -h|--help)           sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

[[ -f "$CFG" ]] || { echo "Nothing to do: $CFG does not exist."; exit 0; }

# ---- read client names from env.yml (no yq) -------------------------------
list_clients() {
  awk '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    /^clients:/ { inclients = 1; next }
    inclients && /^  [A-Za-z0-9_.-]+:[[:space:]]*(#.*)?$/ {
      c = $1; sub(/:$/, "", c); print c
    }
  ' "$ENV_FILE"
}

# ---- decide which profiles to delete --------------------------------------
existing="$(grep -E '^\[.+\]' "$CFG" | tr -d '[]' || true)"

case "$MODE" in
  all)
    targets="$existing"
    ;;
  single)
    targets="$SINGLE"
    ;;
  env)
    [[ -f "$ENV_FILE" ]] || { echo "ERROR: $ENV_FILE not found"; exit 1; }
    targets="$(list_clients)"
    ;;
esac

# Keep only the ones that really exist in the config file
to_delete=""
for p in $targets; do
  if grep -qx "$p" <<< "$existing"; then
    to_delete+="$p"$'\n'
  else
    echo "skip: profile '$p' not found in $CFG"
  fi
done
to_delete="$(echo -n "$to_delete" | sed '/^$/d')"

if [[ -z "$to_delete" ]]; then
  echo "No matching profiles to delete."
  exit 0
fi

echo "The following profiles will be deleted from $CFG:"
sed 's/^/  - /' <<< "$to_delete"

# ---- confirm --------------------------------------------------------------
if [[ "$ASSUME_YES" != "true" ]]; then
  read -r -p "Continue? [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
fi

# ---- backup ---------------------------------------------------------------
backup="$CFG.bak.$(date +%Y%m%d%H%M%S)"
cp "$CFG" "$backup"
chmod 600 "$backup"
echo "Backup saved: $backup"

# ---- delete ---------------------------------------------------------------
remove_section() {
  local profile="$1" tmp
  tmp="$(mktemp)"
  awk -v sec="[$profile]" '
    $0 == sec { skip = 1; next }
    /^\[/     { skip = 0 }
    !skip     { print }
  ' "$CFG" > "$tmp"
  mv "$tmp" "$CFG"
  chmod 600 "$CFG"
}

while read -r p; do
  remove_section "$p"
  echo "deleted: $p"
done <<< "$to_delete"

# ---- optional OAuth token cache cleanup -----------------------------------
if [[ "$CLEAR_CACHE" == "true" ]]; then
  cache="$HOME/.databricks/token-cache.json"
  if [[ -f "$cache" ]]; then
    rm -f "$cache"
    echo "removed OAuth token cache: $cache"
  fi
fi

echo "Done."
