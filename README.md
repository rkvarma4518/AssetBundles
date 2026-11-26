# AssetBundles 

This is the top-level home for everything needed to deliver **one Databricks project to multiple clients**. This README explains the whole folder in simple terms — no technical background needed.

## The big picture

We maintain a data project once, in one place, and deliver a copy of it to each client's private Databricks workspace. This folder holds both halves of that:

1. **The project itself** — the `multi-client-pipeline` folder (the "multi-client-pipeline" bundle).
2. **The connection kit** — the `Create Profile` folder, which sets up saved logins ("profiles") so our tools can reach each client's workspace.

Once the logins exist, the project can be "deployed" — copied into a client's workspace — with a single command per client.

## What's in this folder

| Item | What it is, in plain words |
| --- | --- |
| `multi-client-pipeline/` | The main project. A Databricks automation bundle named **multi-client-pipeline** — a set of files describing one data task that can be delivered to Client A's and Client B's workspaces. Its own README (`demoPI/README.md`) explains it in detail. |
| `Create Profile/` | The connection kit. Small scripts that create and delete the saved logins (profiles) for each client's workspace, driven by one settings file (`env.yml`). Its own README (`Create Profile/README.md`) has full instructions. |
| `temp` | An empty scratch notebook. Nothing important — safe to ignore or delete. |
| `.git/` | The internal bookkeeping of the Git version-control system that keeps the history of every change. Never edit anything in here by hand. |
| `.DS_Store` | A macOS metadata file. Auto-generated, safe to ignore. |

## How the pieces fit together

1. **Set up logins once.** Run the scripts in `Create Profile` to create a saved profile for each client (Client A and Client B). This is like saving each client's address and door key on your computer.
2. **The project references those logins.** Inside `multi-client-pipeline/databricks.yml`, each client "target" points to the matching profile by name.
3. **Deploy.** A single command pushes a copy of the project into that client's workspace. Nothing in this folder is changed by deploying — each client just receives their own copy.

## How to explore it (no coding needed)

* Start here, then read `multi-client-pipeline/README.md` (the project guide), then `Create Profile/README.md` (the login setup guide).
* Each subfolder has its own README so you never have to guess what something is for.
* Reading files can't break anything — feel free to click around.

## For developers (technical quick reference)

This folder is a Git repository (`AssetBundles`, branch `main`) — version-controlled, so every change is tracked and recoverable. The two things you'll do most often:

```
# Create the client logins (once, from the 'Create Profile' folder)
./create-profiles.sh

# Deploy the project to a client's workspace (from the 'demoPI' folder)
databricks bundle deploy --target ClientA
databricks bundle deploy --target clientB
```

See the README inside each subfolder for full details.