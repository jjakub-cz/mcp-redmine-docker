# https://github.com/runekaagaard/mcp-redmine
# To pin a different upstream commit: docker build --build-arg REDMINE_MCP_COMMIT=<sha> .
ARG REDMINE_MCP_COMMIT=0d63b44c67aa1999ab0566c6a6a8b46b2efa6715

FROM python:3.13-slim

ARG REDMINE_MCP_COMMIT
ARG TAG=latest
# Optional: URL to a DER-encoded CA certificate to inject into the certifi bundle.
# Use when your Redmine server has an incomplete certificate chain.
# Example: --build-arg EXTRA_CA_CERT_URL=http://crt.example.com/MyIntermediateCA.crt
ARG EXTRA_CA_CERT_URL=""

WORKDIR /app

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends git && \
    git clone https://github.com/runekaagaard/mcp-redmine.git . && \
    git checkout ${REDMINE_MCP_COMMIT} && \
    rm -rf .git && \
    apt-get purge -y --auto-remove git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# UV_NO_CACHE must be set before uv sync to prevent cache from being written into the image layer
ENV UV_NO_CACHE=1

RUN pip install --no-cache-dir uv \
    && uv sync --frozen --no-dev

# If EXTRA_CA_CERT_URL is set, download the DER certificate and append it to the certifi bundle.
# This is needed when your Redmine server sends an incomplete TLS chain.
RUN if [ -n "${EXTRA_CA_CERT_URL}" ]; then \
        EXTRA_CA_CERT_URL="${EXTRA_CA_CERT_URL}" uv run python -c \
        "import base64,urllib.request,certifi,os; url=os.environ['EXTRA_CA_CERT_URL']; der=urllib.request.urlopen(url).read(); pem=b'-----BEGIN CERTIFICATE-----\n'+base64.encodebytes(der)+b'-----END CERTIFICATE-----\n'; open(certifi.where(),'ab').write(pem)"; \
    fi

# Security: upgrade packages with known CVEs that upstream uv.lock may pin to older versions.
# Review and update these version pins periodically using a Trivy or similar scanner.
RUN uv pip install --no-cache \
    "h11>=0.16.0" \
    "mcp>=1.28.1,<2" \
    "starlette>=1.3.1" \
    "urllib3>=2.7.0" \
    "cryptography>=50.0.0" \
    "python-multipart>=0.0.31" \
    "PyJWT>=2.13.0" \
    "requests>=2.33.0" \
    "python-dotenv>=1.2.2" \
    "idna>=3.15" \
    "Pygments>=2.20.0" \
    "Werkzeug>=3.1.6" \
    "msgpack>=1.2.1" \
    "setuptools>=83.0.0"

RUN find / -xdev -perm /6000 -exec chmod -s {} + 2>/dev/null || true

RUN addgroup --system appgroup && \
    adduser --system --ingroup appgroup --no-create-home appuser && \
    chown -R appuser:appgroup /app

LABEL org.opencontainers.image.title="mcp-redmine" \
      org.opencontainers.image.description="Unofficial Docker packaging of runekaagaard/mcp-redmine" \
      org.opencontainers.image.url="https://github.com/jjakub-cz/mcp-redmine-docker" \
      org.opencontainers.image.source="https://github.com/jjakub-cz/mcp-redmine-docker" \
      org.opencontainers.image.revision="${REDMINE_MCP_COMMIT}" \
      org.opencontainers.image.version="${TAG}"

USER appuser

HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD python -c "import socket; s=socket.create_connection(('localhost',8090),5); s.close()"

CMD ["/app/.venv/bin/mcp-redmine", "--transport", "sse", "--port", "8090"]
