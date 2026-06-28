"""
Demo 02: BYO Agent Reusing Kagent-Registered MCP Tools

Key insight: kagent MCPServer CRD creates a Kubernetes Service.
Any pod in the cluster can connect to it directly via DNS.
BYO agents can reuse tools WITHOUT going through kagent's tool system.

The same MCP server can be used by:
1. Declarative agents (via spec.tools in Agent CRD)
2. BYO agents (via direct HTTP connection, shown here)
"""
import os
from google.adk.agents import Agent
from google.adk.tools.mcp_tool.mcp_toolset import MCPToolset, SseServerParams

# This URL is the Kubernetes Service created by the MCPServer CRD
# Format: http://<mcp-server-name>.<namespace>.svc.cluster.local:<port>
MCP_SERVER_URL = os.environ.get(
    "MCP_SERVER_URL",
    "http://shared-utils.kagent.svc.cluster.local:3000"
)

root_agent = Agent(
    name="byo_mcp_agent",
    model=os.environ.get("AGENT_MODEL", "gemini-2.0-flash"),
    instruction="""You are a helpful assistant with access to shared utilities.
Use generate_id to create unique resource names, current_timestamp to get the
current time, and slugify to convert text into Kubernetes-compatible names.""",
    tools=[
        # Direct connection to the same MCP server that Declarative agents use
        MCPToolset(
            connection_params=SseServerParams(
                url=f"{MCP_SERVER_URL}/sse"
            )
        )
    ],
)
