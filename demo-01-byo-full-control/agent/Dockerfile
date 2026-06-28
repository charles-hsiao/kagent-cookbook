FROM python:3.12-slim

WORKDIR /app

COPY agent/ agent/
COPY pyproject.toml .

# opentelemetry instrumentation packages permanently use beta versioning on PyPI,
# so --pre is required for pip to resolve them.
RUN pip install --no-cache-dir --pre -e .

CMD ["kagent-adk", "run", "agent", "--host", "0.0.0.0", "--port", "8080"]
