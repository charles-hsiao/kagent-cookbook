# Demo 04: Human-in-the-Loop (HITL)

## Problem Addressed

> "I want an AI agent to help manage Kubernetes resources, but I need to approve any changes before they happen."

**Answer: Add `requireApproval` to the tool entries in a Declarative agent — destructive tools pause for human sign-off; read-only tools run freely.**

---

## Core Concept

The `requireApproval` field is a list of tool names that must be approved before executing.
Any tool **not** in the list runs immediately.

```yaml
# Snippet from k8s/hitl-agent.yaml
mcpServer:
  toolNames:
    - k8s_get_resources      # runs freely
    - k8s_apply_manifest     # pauses for approval ↓
  requireApproval:
    - k8s_apply_manifest
```

The flow:

```
User message
  └─> Agent picks a tool
        ├─ Tool in requireApproval?
        │   YES → execution pauses
        │          ├─ Approve → tool runs normally
        │          └─ Reject  → rejection reason sent to LLM; agent adapts
        └─ NO → tool runs immediately
```

`ask_user` is built into every kagent agent — no extra config needed. The agent calls it automatically when the request is ambiguous.

---

## Directory Structure

```
demo-04-hitl/
├── deploy-kind.sh
└── k8s/
    └── hitl-agent.yaml    # Declarative Agent with requireApproval
```

---

## Deployment Steps

### Prerequisites

- kind cluster with kagent installed: `../scripts/kind-setup.sh`

### Deploy

```bash
./deploy-kind.sh
```

### Verify

```bash
kubectl get agent hitl-agent -n kagent
```

---

## Test Scenarios

### 1 — Read without approval

```
List all pods in the kagent namespace
```

`k8s_get_resources` runs immediately — no approval prompt.

### 2 — Approve a create

```
Create a ConfigMap called test-config in the default namespace with key message = "hello from kagent"
```

`k8s_apply_manifest` pauses. Approve/Reject buttons appear with the YAML preview. Click **Approve** → ConfigMap created.

### 3 — Reject a delete

```
Delete the ConfigMap test-config in the default namespace
```

`k8s_delete_resource` pauses. Click **Reject** with a reason — the agent receives the reason and adapts its response.

### 4 — Agent asks for clarification

```
Set up a namespace for my application
```

The request is vague — the agent calls `ask_user` to clarify what the namespace should be called. Answer and it continues.

---

## Key Takeaways

- `requireApproval` is a list field on any `mcpServer` tool entry — no code changes needed
- Read-only tools run freely; write operations pause for approval
- Rejection reasons are sent back to the LLM so it can adjust its approach
- `ask_user` is built-in on every agent — no extra configuration required

---

## Cleanup

```bash
kubectl delete agent hitl-agent -n kagent
```
