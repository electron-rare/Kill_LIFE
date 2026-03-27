FROM python:3.12-slim

WORKDIR /app

# Install uv for fast dependency management
RUN pip install --no-cache-dir uv

# Copy source
COPY pyproject.toml kill_life/ ./
COPY kill_life/ ./kill_life/

# Install dependencies
RUN uv pip install --system .

EXPOSE 8200

CMD ["uvicorn", "kill_life.server:app", "--host", "0.0.0.0", "--port", "8200"]
