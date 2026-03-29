from __future__ import annotations

from ._common import (
    append_session_message,
    clear_session,
    fetch_status_payload,
    load_session,
    open_path,
    remember_session_state,
    repo_root,
    run_intent,
)

try:
    import pcbnew  # type: ignore
    import wx  # type: ignore
except Exception:  # pragma: no cover
    pcbnew = None
    wx = None


INTENTS = [
    "board-review",
    "erc-drc-assist",
    "bom-footprint-audit",
    "ecad-mcad-sync",
]


def _board_path() -> str:
    if pcbnew is None:
        return ""
    try:
        board = pcbnew.GetBoard()
        if board is None:
            return ""
        return board.GetFileName() or ""
    except Exception:
        return ""


def _selection_summary() -> list[str]:
    path = _board_path()
    return [path] if path else []


def _result_message(payload: dict) -> str:
    lines = [
        f"Status: {payload.get('status', 'unknown')}",
        f"Summary: {payload.get('summary', '(no summary)')}",
    ]
    degraded_reasons = payload.get("degraded_reasons") or []
    next_steps = payload.get("next_steps") or []
    if degraded_reasons:
        lines.append("")
        lines.append("Degraded reasons:")
        lines.extend(f"- {item}" for item in degraded_reasons[:4])
    if next_steps:
        lines.append("")
        lines.append("Next steps:")
        lines.extend(f"- {item}" for item in next_steps[:4])
    return "\n".join(lines)


def _transcript_text(session: dict) -> str:
    messages = session.get("messages") or []
    if not messages:
        return "No YiACAD session history yet."
    chunks: list[str] = []
    for item in messages:
        stamp = item.get("created_at") or "unknown-time"
        role = str(item.get("role") or "assistant").upper()
        intent = item.get("intent") or ""
        source_path = item.get("source_path") or ""
        status = item.get("status") or ""
        header = f"[{stamp}] {role}"
        if intent:
            header += f" | {intent}"
        if status:
            header += f" | {status}"
        chunks.append(header)
        if source_path:
            chunks.append(f"source: {source_path}")
        chunks.append(str(item.get("content") or ""))
        chunks.append("")
    return "\n".join(chunks).strip()


if wx is not None:

    class YiACADDialog(wx.Dialog):  # type: ignore[misc]
        def __init__(self) -> None:
            super().__init__(None, title="YiACAD for KiCad", size=(720, 620))
            panel = wx.Panel(self)
            sizer = wx.BoxSizer(wx.VERTICAL)
            session = load_session()
            default_source = _board_path() or session.get("last_source_path") or ""

            self.intent = wx.Choice(panel, choices=INTENTS)
            if session.get("last_intent") in INTENTS:
                self.intent.SetStringSelection(session["last_intent"])
            else:
                self.intent.SetSelection(0)
            self.source = wx.TextCtrl(panel, value=default_source, style=wx.TE_READONLY)
            self.prompt = wx.TextCtrl(
                panel,
                style=wx.TE_MULTILINE,
                value=session.get("last_prompt") or "Describe the KiCad task context for YiACAD. The action run remains deterministic.",
            )
            self.transcript = wx.TextCtrl(panel, style=wx.TE_MULTILINE | wx.TE_READONLY)
            self.refresh_transcript()

            sizer.Add(wx.StaticText(panel, label="Intent"), 0, wx.ALL, 8)
            sizer.Add(self.intent, 0, wx.EXPAND | wx.LEFT | wx.RIGHT, 8)
            sizer.Add(wx.StaticText(panel, label="Board / source path"), 0, wx.ALL, 8)
            sizer.Add(self.source, 0, wx.EXPAND | wx.LEFT | wx.RIGHT, 8)
            sizer.Add(wx.StaticText(panel, label="Transcript"), 0, wx.ALL, 8)
            sizer.Add(self.transcript, 1, wx.EXPAND | wx.LEFT | wx.RIGHT, 8)
            sizer.Add(wx.StaticText(panel, label="Task context"), 0, wx.ALL, 8)
            sizer.Add(self.prompt, 0, wx.EXPAND | wx.LEFT | wx.RIGHT, 8)

            button_row = wx.BoxSizer(wx.HORIZONTAL)
            run_btn = wx.Button(panel, label="Run YiACAD Action")
            status_btn = wx.Button(panel, label="YiACAD Status")
            artifacts_btn = wx.Button(panel, label="Open Artifacts")
            clear_btn = wx.Button(panel, label="Clear Session")
            close_btn = wx.Button(panel, label="Close")

            run_btn.Bind(wx.EVT_BUTTON, self.on_run)
            status_btn.Bind(wx.EVT_BUTTON, self.on_status)
            artifacts_btn.Bind(wx.EVT_BUTTON, self.on_artifacts)
            clear_btn.Bind(wx.EVT_BUTTON, self.on_clear)
            close_btn.Bind(wx.EVT_BUTTON, lambda evt: self.EndModal(wx.ID_OK))

            for button in (run_btn, status_btn, artifacts_btn, clear_btn, close_btn):
                button_row.Add(button, 0, wx.ALL, 6)

            sizer.Add(button_row, 0, wx.ALIGN_RIGHT | wx.ALL, 8)
            panel.SetSizer(sizer)

        def persist_state(self) -> None:
            remember_session_state(
                self.intent.GetStringSelection(),
                self.prompt.GetValue().strip(),
                self.source.GetValue().strip(),
            )

        def refresh_transcript(self) -> None:
            self.transcript.SetValue(_transcript_text(load_session()))
            self.transcript.SetInsertionPointEnd()

        def on_run(self, _event) -> None:
            prompt = self.prompt.GetValue().strip()
            source_path = self.source.GetValue().strip()
            intent = self.intent.GetStringSelection()
            self.persist_state()
            append_session_message(
                "user",
                prompt or "(no additional task context provided)",
                intent=intent,
                source_path=source_path,
            )
            payload = run_intent(
                "yiacad-desktop",
                intent,
                prompt,
                source_path,
                _selection_summary(),
            )
            result_text = _result_message(payload)
            append_session_message(
                "assistant",
                result_text,
                intent=intent,
                source_path=source_path,
                status=str(payload.get("status") or ""),
            )
            self.refresh_transcript()
            icon = wx.ICON_INFORMATION if payload.get("status") == "done" else wx.ICON_WARNING
            wx.MessageBox(result_text, "YiACAD", wx.OK | icon)

        def on_status(self, _event) -> None:
            source_path = self.source.GetValue().strip()
            self.persist_state()
            payload = fetch_status_payload(source_path)
            result_text = _result_message(payload)
            append_session_message(
                "assistant",
                result_text,
                intent="status",
                source_path=source_path,
                status=str(payload.get("status") or ""),
            )
            self.refresh_transcript()
            wx.MessageBox(result_text, "YiACAD Status", wx.OK | wx.ICON_INFORMATION)

        def on_artifacts(self, _event) -> None:
            self.persist_state()
            open_path(repo_root() / "artifacts")

        def on_clear(self, _event) -> None:
            clear_session()
            self.refresh_transcript()

else:

    class YiACADDialog:  # pragma: no cover
        def ShowModal(self) -> None:
            raise RuntimeError("wx is unavailable in the current KiCad runtime")

        def Destroy(self) -> None:
            return None


class YiACADActionPlugin(pcbnew.ActionPlugin if pcbnew is not None else object):  # type: ignore[misc]
    def defaults(self) -> None:
        self.name = "YiACAD"
        self.category = "Kill_LIFE AI-native"
        self.description = "Run YiACAD review, audit, and sync actions from KiCad."
        self.show_toolbar_button = False

    def Run(self) -> None:
        if wx is None:
            raise RuntimeError("wx is unavailable in the current KiCad runtime")
        dialog = YiACADDialog()
        dialog.ShowModal()
        dialog.Destroy()
