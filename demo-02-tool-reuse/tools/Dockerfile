FROM python:3.12-slim

WORKDIR /app

COPY pyproject.toml .
RUN pip install --no-cache-dir -e .

COPY server.py .

# agentgateway executes cmd as a single executable (no shell expansion).
# Wrap the python invocation in a script so the path has no spaces.
RUN printf '#!/bin/sh\nexec python /app/server.py\n' > /app/run.sh \
    && chmod +x /app/run.sh

CMD ["python", "server.py"]
