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

Scan the MCP server(s) in a repository on every pull request:

```yaml
name: MCP security scan
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

Several servers in one repo:

```yaml
        with:
          pat: ${{ secrets.STRAIKER_PAT }}
          paths: |
            packages/search-mcp
            packages/billing-mcp
```

Each path should be a directory that could be installed on its own. The scanner
installs and launches the server from the root of what it receives and does not
search subdirectories for a manifest — point it at a monorepo root and static
analysis still runs, but the dynamic half of the scan silently does not.

### Inputs

| Input | Default | Description |
|---|---|---|
| `pat` | — | **Required.** Straiker PAT; store it as a repository secret |
| `paths` | `.` | Directories to scan, one per line |
| `fail-on` | `high` | Fail at this severity or above; empty to never fail |
| `intensity` | `standard` | `quick`, `standard`, or `deep` |
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

## Credentials

Create a PAT in the Straiker console under **Settings → API keys**. The binary
is public; access is not — every API call requires a PAT, and PATs are issued
per tenant.

`actions/checkout` has already fetched your source by the time the scan runs, so
**no GitHub credential is needed**, including for a private repository.

## Support

Issues with the CLI go to your Straiker contact. This repository holds artifacts
only and does not accept pull requests.
