import os

from azure.ai.projects import AIProjectClient
from azure.ai.projects.models import ExternalAgentDefinition
from azure.identity import DefaultAzureCredential


project_endpoint = os.environ["FOUNDRY_PROJECT_ENDPOINT"]
agent_name = os.getenv("EXTERNAL_AGENT_NAME", "external-agent")
otel_agent_id = os.getenv("OTEL_AGENT_ID", "external-agent-v1")

project = AIProjectClient(
    endpoint=project_endpoint,
    credential=DefaultAzureCredential(),
    allow_preview=True,
)

agent = project.agents.create_version(
    agent_name=agent_name,
    description="Private Agent Framework service hosted in Azure Container Apps.",
    definition=ExternalAgentDefinition(otel_agent_id=otel_agent_id),
)

print(f"Registered external agent: {agent.name}")
print(f"Resolved otel_agent_id: {agent.definition.otel_agent_id}")
