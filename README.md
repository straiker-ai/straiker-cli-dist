# straiker CLI — distribution

Prebuilt binaries and the GitHub Action for the [Straiker](https://straiker.ai)
CLI. **The source lives in a private repository**; only build output and the two
integration files below are published here.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/straiker-ai/straiker-cli-dist/main/install.sh | sh
```

macOS and Linux, amd64 and arm64. The script verifies the release checksum
before installing, and installs `s6r` as an alias for the same binary.

Pin a version, or install somewhere else:

```bash
STRAIKER_VERSION=v0.1.0 STRAIKER_INSTALL=~/.local/bin \
  curl -fsSL https://raw.githubusercontent.com/straiker-ai/straiker-cli-dist/main/install.sh | sh
```

Prefer not to pipe to a shell? Download the archive for your platform from
[Releases](../../releases), verify it against `checksums.txt`, and extract
`straiker` onto your `PATH`.

## GitHub Action

Scan on every pull request:

```yaml
name: Straiker scan
on: [pull_request]

jobs:
  straiker:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: straiker-ai/straiker-cli-dist@v1
        with:
          pat: ${{ secrets.STRAIKER_PAT }}
          fail-on: high
```

`kind` selects the engine — `mcp` (the default), `model`, or `skill`:

```yaml
        with:
          pat: ${{ secrets.STRAIKER_PAT }}
          kind: skill
          paths: skills/pdf-filler
```

A model may be a coordinate rather than a path, in which case Straiker fetches
it and nothing is uploaded:

```yaml
        with:
          pat: ${{ secrets.STRAIKER_PAT }}
          kind: model
          paths: hf:org/our-model
```

Several targets of one kind, one per line:

```yaml
        with:
          pat: ${{ secrets.STRAIKER_PAT }}
          paths: |
            packages/search-mcp
            packages/billing-mcp
```

All three kinds in one workflow, as a matrix — one job per kind, so a failure
names which engine found it:

```yaml
jobs:
  straiker:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        include:
          - { kind: mcp,   paths: packages/search-mcp }
          - { kind: skill, paths: skills/pdf-filler }
          - { kind: model, paths: 'hf:org/our-model' }
    steps:
      - uses: actions/checkout@v4
      - uses: straiker-ai/straiker-cli-dist@v1
        with:
          pat: ${{ secrets.STRAIKER_PAT }}
          kind: ${{ matrix.kind }}
          paths: ${{ matrix.paths }}
          fail-on: high
          artifact-name: straiker-${{ matrix.kind }}
```

`artifact-name` has to vary across the matrix: two jobs uploading under one name
collide.

For `kind: mcp` each path should be a directory that could be installed on its
own. The scanner installs and launches the server from the root of what it
receives and does not search subdirectories for a manifest — point it at a
monorepo root and static analysis still runs, but the dynamic half of the scan
silently does not. Models and skills have no such rule: a model may be a single
weights file and a skill may be an archive.

### Inputs

| Input | Default | Description |
|---|---|---|
| `pat` | — | **Required.** Straiker PAT; store it as a repository secret |
| `kind` | `mcp` | `mcp`, `model`, or `skill` |
| `paths` | `.` | What to scan, one per line. Paths, or coordinates for a model |
| `fail-on` | `high` | Fail at this severity or above; empty to never fail |
| `intensity` | `standard` | `quick`, `standard`, or `deep`. **`kind: mcp` only** — see below |
| `version` | latest | CLI version to install |
| `profile` | `prod` | `prod`, `stage`, or `dev` |
| `exclude` | — | Globs to leave out of the upload, one per line |
| `upload-artifact` | `true` | Upload the report bundle |

### Outputs

The run's summary page gets a table of servers and severity counts; the report
bundle (`report.html`, `metadata.json`, `summary.json`, `preflight.json` per
server, plus `index.json`) uploads as an artifact. `result.sarif` is included
when the scan engine produced one — a re-scan of unchanged code reuses a cached
verdict and writes no new SARIF, so pass `--force` if a pipeline needs it on
every run.

Exit codes: `0` clean · `1` findings at or above the threshold · `2` a scan
errored or its risk is `Unknown`, so the verdict is unknown · `3` CLI or auth
failure.

`2` outranking `1` is deliberate — findings are known bad, an error means we do
not know, and not knowing is worse.

### intensity applies to MCP only

It maps to the AI-pass knobs that only the MCP scanner reads. The model scanner
uses no LLM at all, and the skill scanner's only equivalent switch is whether its
AI pass runs. The CLI treats `--intensity` on either as an error rather than a
no-op — a flag that cannot change the result should say so — so this action
drops it for those kinds instead of passing it through. Setting it alongside
`kind: model` is harmless and ignored.

## Credentials

Create a PAT in the Straiker console under **Settings → API keys**. The binary
is public; access is not — every API call requires a PAT, and PATs are issued
per tenant.

`actions/checkout` has already fetched your source by the time the scan runs, so
**no GitHub credential is needed**, including for a private repository.

## Support

Issues with the CLI go to your Straiker contact. This repository holds artifacts
only and does not accept pull requests.
