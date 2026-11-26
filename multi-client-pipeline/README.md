# multi-client-pipeline

This README explains the whole multi-client-pipeline project in simple terms. You don't need any technical background to follow it — by the end you'll know what the project is, what it does, and how to explore every part of it.

## What is this project?

multi-client-pipeline is a Databricks **automation project**. In plain terms, it is a set of files that describe one data task, plus a tool that copies ("deploys") that task into Databricks for **two different clients** — Client A and Client B — without anyone having to set things up by hand in each place.

A quick analogy: think of this project as a **recipe book** and Databricks as the **kitchen**. The files here are the recipes. "Deploying" means handing the recipes to a kitchen. This project keeps one master copy of the recipes and can hand them to two different kitchens (one per client).

## What is Databricks?

Databricks is a cloud platform companies use to store large amounts of data and run calculations on it. Two building blocks matter here:

* **Notebook** — a document that mixes plain-language notes with runnable code. Ours is `src/sample_notebook`.
* **Job** — a saved task that runs one or more notebooks automatically, like an alarm clock for code.

## What does multi-client-pipeline do today?

The project is a working skeleton with one automated task:

1. The job **build-pipeline** (defined in `resources/buildJob.yml`) runs.
2. It opens the notebook `src/sample_notebook`.
3. That notebook currently just prints "hello world" — a placeholder that proves the whole chain works end to end.

As the project grows, real data work will replace the placeholder inside the notebook, while the setup around it stays the same.

## The two clients ("targets")

The same files can be deployed to two separate Databricks workspaces — the same product delivered to two different customers, each in their own private space:

| Target | Delivers to | Data location |
| --- | --- | --- |
| `ClientA` | Client A's Databricks workspace | `predictpi` catalog, `dev` schema |
| `clientB` | Client B's Databricks workspace | `predictpi` catalog, `dev` schema |

Deploying never changes the project files — it just pushes a copy of the setup into the chosen client's workspace. Both targets are in development mode, so anything deployed there gets a `dev_<your-name>` prefix and stays private to you.

## A tour of the folders

| Folder / file | What it is, in plain words |
| --- | --- |
| `databricks.yml` | The front door. The master settings file: names the project, defines the two client targets, and tells the tool where everything else lives. |
| `resources/` | The task definitions. `buildJob.yml` here describes the job: its name (`build-pipeline`), which notebook it runs, and how. |
| `src/` | The actual work. `sample_notebook` is the notebook the job runs. More code will live here as the project grows. |
| `tests/` | Quality checks. Small programs that automatically verify the project's code still works. |
| `fixtures/` | Sample data, mainly used by the tests. |
| `pyproject.toml` | The project's "shopping list" — which extra Python packages it needs and how it's built. |
| `AGENTS.md` | Instructions for AI coding assistants that help work on this project. |
| `dist/`, `.databricks/`, `.vscode/` | Auto-generated or editor files. Safe to ignore — the tooling manages them. |

## How the pieces fit together

1. `databricks.yml` is read first. It says: "this project is called multi-client-pipeline, it can be deployed to ClientA or clientB, and extra definitions live in `resources/`."
2. `resources/buildJob.yml` says: "there is a job, and its task is to run the notebook at `src/sample_notebook`."
3. When someone runs the job, that notebook executes and its output appears in the client's workspace.

## How to explore it (no coding needed)

* Open the files in this order: `databricks.yml` → `resources/buildJob.yml` → `src/sample_notebook`. Each one is short.
* In the Databricks workspace, deployed jobs appear under **Jobs & Pipelines** — look for the `dev_<your-name>` prefix.
* Just reading the files can't break anything — feel free to click around.


## For developers (technical quick reference)

This is a Databricks Declarative Automation Bundle created from the default-python template. Run bundle commands from the project root with an explicit target — `ClientA` is the currently selected one:

```
databricks bundle validate --target ClientA      # check the configuration
databricks bundle deploy --target ClientA        # deploy to Client A's workspace
databricks bundle run clientA --target ClientA   # run the deployed job (resource key: clientA, name: build-pipeline)
databricks bundle deploy --target clientB        # deploy to Client B's workspace
```

Dependencies are managed with [uv](https://docs.astral.sh/uv/getting-started/installation/):

```
uv sync --dev      # install dependencies
uv run pytest      # run the tests
```

You can work on this project directly in the Databricks workspace, in an IDE like Cursor or VS Code, or from the command line with the Databricks CLI.
