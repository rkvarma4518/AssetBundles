#!/usr/bin/env bash
# Create Databricks CLI profiles for each client defined in env.yml
#
# Usage:
#   ./create-profiles.sh                    # all clients in env.yml
#   ./create-profiles.sh env.yml clienta    # a single client
#
# Requirements: databricks CLI (v0.205+). No yq needed.

set -euo pipefail

ENV_FILE="${1:-env.yml}"
ONLY_CLIENT="${2:-}"
CFG="${DATABRICKS_CONFIG_FILE:-$HOME/.databrickscfg}"

# ---- checks ---------------------------------------------------------------
command -v databricks >/dev/null || { echo "ERROR: databricks CLI not found"; exit 1; }
[[ -f "$ENV_FILE" ]]             || { echo "ERROR: $ENV_FILE not found"; exit 1; }

touch "$CFG"
chmod 600 "$CFG"

# ---- simple env.yml parser (no yq) ----------------------------------------
# Emits lines of: client|key|value
parse_env() {
  awk '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    /^clients:/ { inclients = 1; next }
    inclients && /^  [A-Za-z0-9_.-]+:[[:space:]]*(#.*)?$/ {
      c = $1; sub(/:$/, "", c); next
    }
    inclients && /^    [A-Za-z0-9_]+:/ {
      line = $0; sub(/^[[:space:]]+/, "", line)
      key = line; sub(/:.*/, "", key)
      val = line; sub(/^[^:]+:[[:space:]]*/, "", val)
      sub(/[[:space:]]+#.*$/, "", val)
      sub(/[[:space:]]+$/, "", val)
      gsub(/^"|"$/, "", val)
      gsub(/^\047|\047$/, "", val)
      print c "|" key "|" val
    }
  ' "$ENV_FILE"
}

PARSED="$(parse_env)"

get() {
  awk -F'|' -v c="$1" -v k="$2" '$1==c && $2==k { print $3; exit }' <<< "$PARSED"
}

list_clients() {
  cut -d'|' -f1 <<< "$PARSED" | awk '!seen[$0]++'
}

# ---- helpers --------------------------------------------------------------
# Read the value of the env var whose NAME is stored in env.yml
secret_from_env() {
  local var_name="$1"
  [[ -n "$var_name" ]] || { echo ""; return; }
  echo "${!var_name:-}"
}

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

# ---- main loop ------------------------------------------------------------
if [[ -n "$ONLY_CLIENT" ]]; then
  clients="$ONLY_CLIENT"
else
  clients="$(list_clients)"
fi

for name in $clients; do
  host="$(get "$name" host)"
  auth_type="$(get "$name" auth_type)"

  if [[ -z "$host" || -z "$auth_type" ]]; then
    echo "SKIP  [$name] missing host or auth_type in $ENV_FILE"
    continue
  fi

  case "$auth_type" in
    pat)
      token="$(secret_from_env "$(get "$name" token_env)")"
      if [[ -z "$token" ]]; then
        echo "SKIP  [$name] env var '$(get "$name" token_env)' is not set"
        continue
      fi
      remove_section "$name"
      {
        echo "[$name]"
        echo "host  = $host"
        echo "token = $token"
        echo
      } >> "$CFG"
      echo "OK    [$name] PAT profile written"
      ;;

    service_principal)
      cid="$(secret_from_env "$(get "$name" client_id_env)")"
      csec="$(secret_from_env "$(get "$name" client_secret_env)")"
      if [[ -z "$cid" || -z "$csec" ]]; then
        echo "SKIP  [$name] client id/secret env vars are not set"
        continue
      fi
      remove_section "$name"
      {
        echo "[$name]"
        echo "host          = $host"
        echo "client_id     = $cid"
        echo "client_secret = $csec"
        echo
      } >> "$CFG"
      echo "OK    [$name] service principal profile written"
      ;;

    oauth)
      echo "...   [$name] starting OAuth login (browser will open)"
      databricks auth login --host "$host" --profile "$name"
      echo "OK    [$name] OAuth profile created"
      ;;

    *)
      echo "SKIP  [$name] unknown auth_type '$auth_type' (use pat | oauth | service_principal)"
      continue
      ;;
  esac

  # Verify the profile works
  if databricks current-user me --profile "$name" >/dev/null 2>&1; then
    echo "      verified: $name can authenticate"
  else
    echo "WARN  [$name] profile saved but authentication check failed"
  fi
done

echo
echo "Profiles now in $CFG:"
databricks auth profiles 2>/dev/null || grep '^\[' "$CFG"
