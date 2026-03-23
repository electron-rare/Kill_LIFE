from __future__ import annotations

from ._common import fetch_status_payload, open_path, queue_request, repo_root

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


class YiACADDialog(wx.Dialog):  # type: ignore[misc]
    def __init__(self) -> None:
        super().__init__(None, title="YiACAD AI for KiCad", size=(540, 420))
        panel = wx.Panel(self)
        sizer = wx.BoxSizer(wx.VERTICAL)

        self.intent = wx.Choice(panel, choices=INTENTS)
        self.intent.SetSelection(0)
        self.source = wx.TextCtrl(panel, value=_board_path(), style=wx.TE_READONLY)
        self.prompt = wx.TextCtrl(panel, style=wx.TE_MULTILINE, value="Describe the KiCad task to queue for YiACAD.")

        sizer.Add(wx.StaticText(panel, label="Intent"), 0, wx.ALL, 8)
        sizer.Add(self.intent, 0, wx.EXPAND | wx.LEFT | wx.RIGHT, 8)
        sizer.Add(wx.StaticText(panel, label="Board / source path"), 0, wx.ALL, 8)
        sizer.Add(self.source, 0, wx.EXPAND | wx.LEFT | wx.RIGHT, 8)
        sizer.Add(wx.StaticText(panel, label="Prompt"), 0, wx.ALL, 8)
        sizer.Add(self.prompt, 1, wx.EXPAND | wx.LEFT | wx.RIGHT, 8)

        button_row = wx.BoxSizer(wx.HORIZONTAL)
        queue_btn = wx.Button(panel, label="Queue AI Request")
        status_btn = wx.Button(panel, label="YiACAD Status")
        artifacts_btn = wx.Button(panel, label="Open Artifacts")
        close_btn = wx.Button(panel, label="Close")

        queue_btn.Bind(wx.EVT_BUTTON, self.on_queue)
        status_btn.Bind(wx.EVT_BUTTON, self.on_status)
        artifacts_btn.Bind(wx.EVT_BUTTON, self.on_artifacts)
        close_btn.Bind(wx.EVT_BUTTON, lambda evt: self.EndModal(wx.ID_OK))

        for button in (queue_btn, status_btn, artifacts_btn, close_btn):
            button_row.Add(button, 0, wx.ALL, 6)

        sizer.Add(button_row, 0, wx.ALIGN_RIGHT | wx.ALL, 8)
        panel.SetSizer(sizer)

    def on_queue(self, _event) -> None:
        payload = queue_request(
            "kicad",
            self.intent.GetStringSelection(),
            self.prompt.GetValue().strip(),
            self.source.GetValue().strip(),
            _selection_summary(),
        )
        wx.MessageBox(
            f"Queued request:\n{payload.get('request_path', '')}",
            "YiACAD",
            wx.OK | wx.ICON_INFORMATION,
        )

    def on_status(self, _event) -> None:
        payload = fetch_status_payload()
        lines = payload.get("yiacad_status_excerpt") or []
        summary = "\n".join(lines[:8]) if lines else "No YiACAD status snapshot yet."
        latest_request = payload.get("latest_request") or "(none)"
        wx.MessageBox(
            f"Latest request:\n{latest_request}\n\nStatus:\n{summary}",
            "YiACAD Status",
            wx.OK | wx.ICON_INFORMATION,
        )

    def on_artifacts(self, _event) -> None:
        open_path(repo_root() / "artifacts")


class YiACADActionPlugin(pcbnew.ActionPlugin if pcbnew is not None else object):  # type: ignore[misc]
    def defaults(self) -> None:
        self.name = "YiACAD AI Bridge"
        self.category = "Kill_LIFE AI-native"
        self.description = "Queue KiCad AI tasks into YiACAD and inspect the latest CAD status."
        self.show_toolbar_button = False

    def Run(self) -> None:
        if wx is None:
            raise RuntimeError("wx is unavailable in the current KiCad runtime")
        dialog = YiACADDialog()
        dialog.ShowModal()
        dialog.Destroy()
