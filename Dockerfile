FROM python:3.12-slim

WORKDIR /app

# Install uv for fast dependency management
RUN pip install --no-cache-dir uv

# Copy dependency definition first (cache layer)
COPY pyproject.toml .

# Install dependencies
RUN uv pip install --system -e "."

# Copy source
COPY . .

EXPOSE 8200

CMD ["uvicorn", "kill_life.server:app", "--host", "0.0.0.0", "--port", "8200"]
