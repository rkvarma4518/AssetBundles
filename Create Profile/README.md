# Databricks CLI Profile Scripts

Scripts to create and delete Databricks CLI profiles for multiple clients, driven by a single `env.yml` file. Useful when you deploy Databricks Asset Bundles to a different workspace per client.

## Files

| File | Purpose |
|------|---------|
| `env.yml` | Per-client settings (workspace host, auth type, names of secret env vars) |
| `create-profiles.sh` | Creates a profile in `~/.databrickscfg` for each client in `env.yml` |
| `delete-profiles.sh` | Deletes profiles from `~/.databrickscfg` |

## Prerequisites

- **Databricks CLI** v0.205 or newer (`databricks -v`)
  - macOS/Linux: `brew tap databricks/tap && brew install databricks`
  - Windows: `winget install Databricks.DatabricksCLI`
- **yq** (mikefarah, v4+), used to read `env.yml`
  - macOS/Linux: `brew install yq`
  - Windows: `winget install MikeFarah.yq`
- **Bash** (Linux, macOS, WSL, or Git Bash on Windows)
- A **user or service principal** in each client workspace. You cannot create a profile without an identity in that workspace, so ask the client admin to add you or create a service principal.

## Configuration: `env.yml`

```yaml
clients:
  clienta:
    host: https://adb-1111111111111111.1.azuredatabricks.net
    auth_type: pat
    token_env: CLIENTA_DATABRICKS_TOKEN

  clientb:
    host: https://dbc-xxxxxxxx-xxxx.cloud.databricks.com
    auth_type: oauth

  clientc:
    host: https://adb-2222222222222222.2.azuredatabricks.net
    auth_type: service_principal
    client_id_env: CLIENTC_DATABRICKS_CLIENT_ID
    client_secret_env: CLIENTC_DATABRICKS_CLIENT_SECRET
```

The key under `clients:` becomes the profile name.

| Key | Required for | Description |
|-----|--------------|-------------|
| `host` | all | Workspace URL |
| `auth_type` | all | `pat`, `oauth`, or `service_principal` |
| `token_env` | `pat` | Name of the env var holding the personal access token |
| `client_id_env` | `service_principal` | Name of the env var holding the client ID |
| `client_secret_env` | `service_principal` | Name of the env var holding the client secret |

**Secrets are never stored in `env.yml`.** The `*_env` keys hold only the *names* of environment variables, so the file is safe to commit.

## Creating profiles

1. Export the secrets referenced in `env.yml`:

   ```bash
   export CLIENTA_DATABRICKS_TOKEN="dapiXXXXXXXXXXXX"
   export CLIENTC_DATABRICKS_CLIENT_ID="xxxx-xxxx"
   export CLIENTC_DATABRICKS_CLIENT_SECRET="xxxx"
   ```

2. Run the script:

   ```bash
   chmod +x create-profiles.sh

   ./create-profiles.sh                    # all clients in env.yml
   ./create-profiles.sh env.yml clienta    # one client only
   ```

### What it does

| `auth_type` | Behavior |
|-------------|----------|
| `pat` | Writes `host` and `token` to the profile |
| `service_principal` | Writes `host`, `client_id`, and `client_secret` |
| `oauth` | Runs `databricks auth login`; a browser opens for sign-in |

- Re-running replaces an existing profile with the same name (no duplicates).
- Clients with missing settings or unset env vars are skipped with a message.
- After creating each profile, it verifies authentication with `databricks current-user me`.
- `~/.databrickscfg` is set to permission `600`.

### Verify

```bash
databricks auth profiles
databricks clusters list --profile clienta
```

## Deleting profiles

```bash
chmod +x delete-profiles.sh

./delete-profiles.sh                       # only clients listed in env.yml
./delete-profiles.sh --profile clienta     # one profile by name
./delete-profiles.sh --all                 # EVERY profile in ~/.databrickscfg
./delete-profiles.sh --yes                 # skip the confirmation prompt
./delete-profiles.sh --clear-oauth-cache   # also remove cached OAuth tokens
./delete-profiles.sh --env other.yml       # use a different env file
```

### Options

| Option | Description |
|--------|-------------|
| *(none)* | Delete only the clients listed in `env.yml` |
| `--all` | Delete every profile in `~/.databrickscfg` |
| `--profile NAME` | Delete a single profile |
| `--env FILE` | Use a different env file |
| `--yes`, `-y` | Skip the confirmation prompt |
| `--clear-oauth-cache` | Delete `~/.databricks/token-cache.json` |

### Safety

- Lists the profiles to be deleted and asks for confirmation.
- Creates a timestamped backup first (`~/.databrickscfg.bak.YYYYMMDDHHMMSS`). To restore:

  ```bash
  cp ~/.databrickscfg.bak.<timestamp> ~/.databrickscfg
  ```

- Profiles that don't exist are skipped.

### Important notes

- Deleting a PAT profile only removes it **locally**. The token stays valid in the workspace until revoked (*User Settings → Developer → Access tokens*).
- `--clear-oauth-cache` clears tokens for **all** OAuth profiles, not just the deleted ones. You'll need to log in again for any you keep.
- Backup files contain tokens in plain text. Delete old backups when no longer needed.

## Using the profiles with Asset Bundles

Define one target per client in `databricks.yml`, referencing the profile name:

```yaml
targets:
  clienta:
    workspace:
      host: https://adb-1111111111111111.1.azuredatabricks.net
      profile: clienta

  clientb:
    workspace:
      host: https://dbc-xxxxxxxx-xxxx.cloud.databricks.com
      profile: clientb
```

Deploy to each client:

```bash
databricks bundle validate -t clienta
databricks bundle deploy   -t clienta

# or loop over all clients
for c in clienta clientb clientc; do
  databricks bundle deploy -t "$c"
done
```

The profile name in the target must match the profile created by `create-profiles.sh`, and the host should match too.

## Security tips

- Never commit tokens, secrets, `~/.databrickscfg`, or its backups to git.
- If you keep secrets in a `.env` file, add it to `.gitignore`.
- Prefer OAuth or service principals over long-lived PATs.
- Use a separate identity per client so access is auditable and revocable.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `yq not found` | Install mikefarah yq v4+ (not the Python `yq`) |
| `SKIP [client] env var ... is not set` | Export the secret env var before running the script |
| `WARN ... authentication check failed` | Check the host URL, token validity, and that the identity has workspace access |
| Host mismatch error during `bundle deploy` | Make sure `host` in the bundle target matches the host in the profile |
| OAuth browser doesn't open | Run `databricks auth login --host <url> --profile <name>` manually |
