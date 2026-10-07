# mcp-redmine-docker

Unofficial Docker packaging of [runekaagaard/mcp-redmine](https://github.com/runekaagaard/mcp-redmine) — an MCP server that gives Claude Code access to Redmine.

The upstream project does not publish releases or Docker images. This repo fills that gap: it pins a specific upstream commit, builds a hardened image, and publishes it to GHCR via GitHub Actions on each release.

## Quick start

```bash
cp .env.example .env
# Edit .env — set REDMINE_URL and REDMINE_API_KEY
docker compose up -d
```

The MCP server is then available at `http://localhost:8090/sse`.

### Connect Claude Code

```bash
claude mcp add --transport sse --scope user redmine http://localhost:8090/sse
```

## Configuration

All configuration is via environment variables (`.env` file or host environment):

| Variable | Required | Description |
|----------|----------|-------------|
| `REDMINE_URL` | Yes | Your Redmine instance URL (e.g. `https://redmine.example.com`) |
| `REDMINE_API_KEY` | Yes | Redmine API key for the user or service account |
| `REDMINE_DANGEROUSLY_ACCEPT_INVALID_CERTS` | No | Set to `1` to disable SSL verification. Not recommended for production. |
| `REDMINE_ALLOWED_DIRECTORIES` | No | Allowed directories for file upload/download. Empty = file ops disabled. |
| `REDMINE_HEADERS` | No | Extra HTTP headers sent to Redmine (`"Header1: Val1, Header2: Val2"`). |

## Versioning and upstream pinning

This project does not track upstream semver — the upstream project does not publish releases.

Instead, each release of this repo uses the **upstream commit SHA** as its tag. When you create a release with tag `abc1234...`, the CI pipeline builds the image with `REDMINE_MCP_COMMIT=abc1234...`, clones that exact commit from `runekaagaard/mcp-redmine`, and publishes the image.

```
ghcr.io/jjakub-cz/mcp-redmine-docker:0d63b44c67aa1999ab0566c6a6a8b46b2efa6715
ghcr.io/jjakub-cz/mcp-redmine-docker:latest
```

To upgrade to a newer upstream commit:
1. Find the commit SHA you want from [runekaagaard/mcp-redmine](https://github.com/runekaagaard/mcp-redmine/commits/main/)
2. Create a new GitHub release in this repo with the **first 7–12 characters** of that SHA as the tag name (e.g. `0d63b44`). GitHub does not allow full 40-character SHA strings as tag names.
3. CI builds and publishes the image automatically — `git checkout <short-sha>` resolves correctly inside the Docker build.

## Build locally

```bash
docker build \
  --build-arg REDMINE_MCP_COMMIT=0d63b44c67aa1999ab0566c6a6a8b46b2efa6715 \
  -t mcp-redmine:local .
```

Or with docker compose (uses the default commit baked into the Dockerfile):

```bash
docker compose up --build
```

## Custom CA certificate

If your Redmine server sends an incomplete TLS certificate chain, you can inject an additional CA certificate into the image at build time:

```bash
docker build \
  --build-arg EXTRA_CA_CERT_URL=http://crt.example.com/MyIntermediateCA.crt \
  -t mcp-redmine:local .
```

`EXTRA_CA_CERT_URL` must point to a DER-encoded certificate. It is downloaded during the build and appended to the `certifi` CA bundle used by the MCP server.

## Security

- Runs as a non-root system user (`appuser`)
- SUID/SGID bits stripped from all binaries
- `no-new-privileges` enforced in docker-compose
- CVE patches: packages with known vulnerabilities pinned to upstream `uv.lock` are upgraded at build time. Review and update the version pins in the Dockerfile periodically.

## Authentication

The server itself has no built-in authentication. If you expose it beyond localhost, put an authenticating reverse proxy (nginx, Caddy, Traefik) in front of it.

## License

This packaging is MIT licensed. The upstream project [runekaagaard/mcp-redmine](https://github.com/runekaagaard/mcp-redmine) has its own license.
