"""
Custom MCP tool server — deployed as a kagent MCPServer CRD.
Provides simple utilities that any agent in the cluster can reuse.
"""
import re
import random
import string
from datetime import datetime, timezone
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("shared-utils")


@mcp.tool()
def generate_id(prefix: str = "", length: int = 8) -> str:
    """Generate a random alphanumeric ID, optionally with a prefix.

    Useful for creating unique Kubernetes resource names.
    Example: generate_id("job", 6) → "job-a3f9bk"
    """
    chars = string.ascii_lowercase + string.digits
    random_part = "".join(random.choices(chars, k=length))
    return f"{prefix}-{random_part}" if prefix else random_part


@mcp.tool()
def current_timestamp(fmt: str = "iso") -> str:
    """Return the current UTC timestamp.

    fmt options:
      "iso"   → 2025-06-28T10:30:00Z
      "unix"  → 1751104200
      "date"  → 2025-06-28
    """
    now = datetime.now(timezone.utc)
    if fmt == "unix":
        return str(int(now.timestamp()))
    if fmt == "date":
        return now.strftime("%Y-%m-%d")
    return now.strftime("%Y-%m-%dT%H:%M:%SZ")


@mcp.tool()
def slugify(text: str) -> str:
    """Convert text to a Kubernetes-compatible resource name (lowercase, hyphens only).

    Example: slugify("My App 2.0!") → "my-app-2-0"
    """
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", "-", text)
    return text.strip("-")


if __name__ == "__main__":
    mcp.run(transport="stdio")
