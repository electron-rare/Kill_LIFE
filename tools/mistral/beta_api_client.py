#!/usr/bin/env python3
"""
Mistral Beta Conversations API client wrapper.

Provides a structured client for the Mistral Beta Conversations API,
compatible with the existing mistral_agents_tui.sh interface.

Environment:
  MISTRAL_API_URL  — API base URL (default: https://api.mistral.ai)
  MISTRAL_API_KEY  — API key for authentication

Usage:
  from tools.mistral.beta_api_client import MistralBetaClient

  client = MistralBetaClient()
  conv = client.create_conversation(agent_id="ag_xxx")
  resp = client.send_message(conv["id"], "Hello")
  convs = client.list_conversations()
"""
from __future__ import annotations

import os
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

import httpx


# ---------------------------------------------------------------------------
# Agent registry (mirrors mistral_agents_tui.sh agent IDs)
# ---------------------------------------------------------------------------

AGENT_IDS = {
    "sentinelle": os.environ.get(
        "MISTRAL_AGENT_SENTINELLE_ID",
        "ag_019d124c302375a8bf06f9ff8a99fb5f",
    ),
    "tower": os.environ.get(
        "MISTRAL_AGENT_TOWER_ID",
        "ag_019d124e760877359ad3ff5031179ebc",
    ),
    "forge": os.environ.get(
        "MISTRAL_AGENT_FORGE_ID",
        "ag_019d1251023f73258b80ac73f90458f6",
    ),
    "devstral": os.environ.get(
        "MISTRAL_AGENT_DEVSTRAL_ID",
        "ag_019d125348eb77e880df33acbd395efa",
    ),
}


# ---------------------------------------------------------------------------
# Response types
# ---------------------------------------------------------------------------

@dataclass
class ConversationInfo:
    """Metadata for a Beta API conversation."""
    id: str = ""
    agent_id: str = ""
    created_at: str = ""
    status: str = "active"
    metadata: Dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "agent_id": self.agent_id,
            "created_at": self.created_at,
            "status": self.status,
            "metadata": self.metadata,
        }


@dataclass
class MessageResponse:
    """Response from send_message."""
    conversation_id: str = ""
    content: str = ""
    role: str = "assistant"
    usage: Dict[str, int] = field(default_factory=dict)
    model: str = ""
    raw: Dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "conversation_id": self.conversation_id,
            "content": self.content,
            "role": self.role,
            "usage": self.usage,
            "model": self.model,
        }


# ---------------------------------------------------------------------------
# Client
# ---------------------------------------------------------------------------

class MistralBetaClient:
    """
    Wrapper for the Mistral Beta Conversations API.

    Provides create_conversation, send_message, list_conversations methods
    that map to the Beta API endpoints, with fallback awareness for the
    deprecated /v1/agents/completions endpoint.
    """

    def __init__(
        self,
        api_url: Optional[str] = None,
        api_key: Optional[str] = None,
        timeout: float = 60.0,
    ):
        self.api_url = (api_url or os.environ.get("MISTRAL_API_URL", "https://api.mistral.ai")).rstrip("/")
        self.api_key = api_key or os.environ.get("MISTRAL_API_KEY", "")
        self.timeout = timeout
        self._client: Optional[httpx.Client] = None

    # -- HTTP plumbing --

    @property
    def _headers(self) -> Dict[str, str]:
        return {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        }

    @property
    def client(self) -> httpx.Client:
        if self._client is None or self._client.is_closed:
            self._client = httpx.Client(
                base_url=self.api_url,
                headers=self._headers,
                timeout=self.timeout,
            )
        return self._client

    def close(self) -> None:
        if self._client and not self._client.is_closed:
            self._client.close()

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.close()

    # -- Conversation endpoints (Beta API) --

    def create_conversation(
        self,
        agent_id: Optional[str] = None,
        agent_name: Optional[str] = None,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> ConversationInfo:
        """
        Create a new conversation with a Mistral agent.

        Args:
            agent_id: Direct agent ID (takes precedence).
            agent_name: Agent name from registry (sentinelle, tower, forge, devstral).
            metadata: Optional metadata to attach to the conversation.

        Returns:
            ConversationInfo with the new conversation details.
        """
        resolved_id = agent_id or AGENT_IDS.get(agent_name or "", "")
        if not resolved_id:
            raise ValueError(
                f"No agent_id provided and '{agent_name}' not in registry. "
                f"Available: {list(AGENT_IDS.keys())}"
            )

        payload: Dict[str, Any] = {
            "agent_id": resolved_id,
        }
        if metadata:
            payload["metadata"] = metadata

        resp = self.client.post("/v1/conversations", json=payload)
        resp.raise_for_status()
        data = resp.json()

        return ConversationInfo(
            id=data.get("id", ""),
            agent_id=resolved_id,
            created_at=data.get("created_at", ""),
            status=data.get("status", "active"),
            metadata=data.get("metadata", {}),
        )

    def send_message(
        self,
        conversation_id: str,
        content: str,
        *,
        role: str = "user",
        temperature: Optional[float] = None,
        max_tokens: Optional[int] = None,
    ) -> MessageResponse:
        """
        Send a message in an existing conversation.

        Args:
            conversation_id: ID from create_conversation.
            content: User message text.
            role: Message role (default "user").
            temperature: Override agent temperature.
            max_tokens: Override max tokens.

        Returns:
            MessageResponse with the assistant's reply.
        """
        payload: Dict[str, Any] = {
            "conversation_id": conversation_id,
            "messages": [{"role": role, "content": content}],
        }
        if temperature is not None:
            payload["temperature"] = temperature
        if max_tokens is not None:
            payload["max_tokens"] = max_tokens

        resp = self.client.post("/v1/conversations/completions", json=payload)
        resp.raise_for_status()
        data = resp.json()

        # Extract assistant message from choices
        choices = data.get("choices", [])
        assistant_content = ""
        if choices:
            msg = choices[0].get("message", {})
            assistant_content = msg.get("content", "")

        return MessageResponse(
            conversation_id=conversation_id,
            content=assistant_content,
            role="assistant",
            usage=data.get("usage", {}),
            model=data.get("model", ""),
            raw=data,
        )

    def list_conversations(
        self,
        agent_id: Optional[str] = None,
        agent_name: Optional[str] = None,
        limit: int = 20,
        offset: int = 0,
    ) -> List[ConversationInfo]:
        """
        List existing conversations, optionally filtered by agent.

        Args:
            agent_id: Filter by agent ID.
            agent_name: Filter by agent name from registry.
            limit: Max results per page.
            offset: Pagination offset.

        Returns:
            List of ConversationInfo.
        """
        params: Dict[str, Any] = {"limit": limit, "offset": offset}
        resolved_id = agent_id or AGENT_IDS.get(agent_name or "", "")
        if resolved_id:
            params["agent_id"] = resolved_id

        resp = self.client.get("/v1/conversations", params=params)
        resp.raise_for_status()
        data = resp.json()

        conversations = []
        for item in data.get("data", data.get("conversations", [])):
            conversations.append(ConversationInfo(
                id=item.get("id", ""),
                agent_id=item.get("agent_id", ""),
                created_at=item.get("created_at", ""),
                status=item.get("status", "active"),
                metadata=item.get("metadata", {}),
            ))
        return conversations

    # -- Deprecated endpoint (fallback) --

    def send_message_deprecated(
        self,
        agent_id: Optional[str] = None,
        agent_name: Optional[str] = None,
        messages: Optional[List[Dict[str, str]]] = None,
        *,
        temperature: Optional[float] = None,
        max_tokens: Optional[int] = None,
    ) -> MessageResponse:
        """
        Fallback to deprecated /v1/agents/completions endpoint.
        Stateless — no conversation persistence.

        Args:
            agent_id: Direct agent ID.
            agent_name: Agent name from registry.
            messages: List of {"role": ..., "content": ...} dicts.
            temperature: Override temperature.
            max_tokens: Override max tokens.

        Returns:
            MessageResponse.
        """
        resolved_id = agent_id or AGENT_IDS.get(agent_name or "", "")
        if not resolved_id:
            raise ValueError(f"No agent_id for '{agent_name}'")

        payload: Dict[str, Any] = {
            "agent_id": resolved_id,
            "messages": messages or [],
        }
        if temperature is not None:
            payload["temperature"] = temperature
        if max_tokens is not None:
            payload["max_tokens"] = max_tokens

        resp = self.client.post("/v1/agents/completions", json=payload)
        resp.raise_for_status()
        data = resp.json()

        choices = data.get("choices", [])
        assistant_content = ""
        if choices:
            msg = choices[0].get("message", {})
            assistant_content = msg.get("content", "")

        return MessageResponse(
            content=assistant_content,
            role="assistant",
            usage=data.get("usage", {}),
            model=data.get("model", ""),
            raw=data,
        )

    # -- Convenience shortcuts --

    def chat(
        self,
        agent_name: str,
        message: str,
        *,
        conversation_id: Optional[str] = None,
        temperature: Optional[float] = None,
        max_tokens: Optional[int] = None,
    ) -> MessageResponse:
        """
        High-level chat: creates conversation if needed, sends message.

        Compatible with mistral_agents_tui.sh call pattern.
        """
        if conversation_id is None:
            conv = self.create_conversation(agent_name=agent_name)
            conversation_id = conv.id

        return self.send_message(
            conversation_id,
            message,
            temperature=temperature,
            max_tokens=max_tokens,
        )

    def health_check(self) -> Dict[str, Any]:
        """
        Ping all registered agents via the Beta API.

        Returns dict with agent_name -> {"status": "ok"|"error", ...}.
        """
        results: Dict[str, Any] = {}
        for name, agent_id in AGENT_IDS.items():
            try:
                conv = self.create_conversation(agent_id=agent_id)
                results[name] = {
                    "status": "ok",
                    "agent_id": agent_id,
                    "conversation_id": conv.id,
                }
            except Exception as e:
                results[name] = {
                    "status": "error",
                    "agent_id": agent_id,
                    "error": str(e),
                }
        return results

    # -- TUI compatibility --

    def format_for_tui(self, response: MessageResponse) -> str:
        """Format a response for TUI display (compatible with mistral_agents_tui.sh)."""
        usage = response.usage
        tokens_in = usage.get("prompt_tokens", 0)
        tokens_out = usage.get("completion_tokens", 0)
        return (
            f"Model: {response.model}\n"
            f"Tokens: {tokens_in} in / {tokens_out} out\n"
            f"---\n"
            f"{response.content}"
        )


# ---------------------------------------------------------------------------
# CLI for testing
# ---------------------------------------------------------------------------

def _cli():
    import argparse
    import json

    parser = argparse.ArgumentParser(description="Mistral Beta API Client CLI")
    sub = parser.add_subparsers(dest="command")

    # health
    sub.add_parser("health", help="Check all agents")

    # chat
    chat_p = sub.add_parser("chat", help="Chat with an agent")
    chat_p.add_argument("agent", choices=list(AGENT_IDS.keys()))
    chat_p.add_argument("message", nargs="?", default="ping")

    # list
    list_p = sub.add_parser("list", help="List conversations")
    list_p.add_argument("--agent", choices=list(AGENT_IDS.keys()), default=None)

    args = parser.parse_args()

    client = MistralBetaClient()

    if args.command == "health":
        result = client.health_check()
        print(json.dumps(result, indent=2))

    elif args.command == "chat":
        resp = client.chat(args.agent, args.message)
        print(client.format_for_tui(resp))

    elif args.command == "list":
        convs = client.list_conversations(agent_name=args.agent)
        for c in convs:
            print(json.dumps(c.to_dict(), indent=2))

    else:
        parser.print_help()


if __name__ == "__main__":
    _cli()
