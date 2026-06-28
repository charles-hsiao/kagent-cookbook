import os
from google.adk.agents import Agent
from google.adk.tools.mcp_tool.mcp_toolset import MCPToolset, SseConnectionParams

# Kubernetes Service created by the MCPServer CRD
# Format: http://<mcp-server-name>.<namespace>.svc.cluster.local:<port>
MCP_SERVER_URL = os.environ.get(
    "MCP_SERVER_URL",
    "http://shared-utils.kagent.svc.cluster.local:3000"
)

root_agent = Agent(
    name="byo_mcp_agent",
    model=os.environ.get("AGENT_MODEL", "gemini-2.5-flash"),
    instruction="""You are a helpful assistant with access to shared utilities.
Use generate_id to create unique resource names, current_timestamp to get the
current time, and slugify to convert text into Kubernetes-compatible names.""",
    tools=[
        # Direct connection to the same MCP server that Declarative agents use
        MCPToolset(
            connection_params=SseConnectionParams(
                url=f"{MCP_SERVER_URL}/sse"
            )
        )
    ],
)
