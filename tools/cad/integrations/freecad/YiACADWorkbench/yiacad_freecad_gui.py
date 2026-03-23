from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

import FreeCAD  # type: ignore
import FreeCADGui  # type: ignore

try:
    from PySide2 import QtWidgets  # type: ignore
except Exception:  # pragma: no cover
    from PySide import QtGui as QtWidgets  # type: ignore


def _candidate_roots() -> list[Path]:
    candidates: list[Path] = []
    if os.environ.get("KILL_LIFE_ROOT"):
        candidates.append(Path(os.environ["KILL_LIFE_ROOT"]).expanduser())
    here = Path(__file__).resolve()
    candidates.extend(here.parents)
    return candidates


def repo_root() -> Path:
    for candidate in _candidate_roots():
        bridge = candidate / "tools" / "cad" / "yiacad_ai_bridge.py"
        if bridge.exists():
            return candidate
    raise RuntimeError("Unable to locate Kill_LIFE root for YiACAD bridge")


def bridge_script() -> Path:
    return repo_root() / "tools" / "cad" / "yiacad_ai_bridge.py"


def run_bridge(args: list[str]) -> dict:
    proc = subprocess.run(
        ["python3", str(bridge_script()), *args],
        cwd=repo_root(),
        text=True,
        capture_output=True,
        check=False,
        timeout=30,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or proc.stdout.strip() or "YiACAD bridge failed")
    return json.loads(proc.stdout.strip() or "{}")


def current_document_path() -> str:
    doc = FreeCAD.ActiveDocument
    if doc is None:
        return ""
    return str(getattr(doc, "FileName", "") or "")


def selection_summary() -> list[str]:
    selected = []
    for item in FreeCADGui.Selection.getSelectionEx():
        if getattr(item, "ObjectName", None):
            selected.append(str(item.ObjectName))
    return selected


def _status_summary() -> str:
    payload = run_bridge(["status"])
    lines = payload.get("yiacad_status_excerpt") or []
    latest_request = payload.get("latest_request") or "(none)"
    excerpt = "\n".join(lines[:8]) if lines else "No YiACAD status snapshot yet."
    return f"Latest request:\n{latest_request}\n\nStatus:\n{excerpt}"


def show_status_message() -> None:
    QtWidgets.QMessageBox.information(None, "YiACAD Status", _status_summary())


def open_artifacts() -> None:
    subprocess.Popen(["open", str(repo_root() / "artifacts")])


class YiACADDialog(QtWidgets.QDialog):
    def __init__(self) -> None:
        super().__init__(None)
        self.setWindowTitle("YiACAD AI for FreeCAD")
        self.resize(560, 420)

        layout = QtWidgets.QVBoxLayout(self)

        self.intent = QtWidgets.QComboBox(self)
        self.intent.addItems(
            [
                "model-assist",
                "parametric-refactor",
                "step-export-review",
                "ecad-mcad-sync",
            ]
        )
        self.source = QtWidgets.QLineEdit(self)
        self.source.setReadOnly(True)
        self.source.setText(current_document_path())
        self.prompt = QtWidgets.QPlainTextEdit(self)
        self.prompt.setPlainText("Describe the FreeCAD task to queue for YiACAD.")

        layout.addWidget(QtWidgets.QLabel("Intent", self))
        layout.addWidget(self.intent)
        layout.addWidget(QtWidgets.QLabel("Document / source path", self))
        layout.addWidget(self.source)
        layout.addWidget(QtWidgets.QLabel("Prompt", self))
        layout.addWidget(self.prompt)

        button_row = QtWidgets.QHBoxLayout()
        queue_button = QtWidgets.QPushButton("Queue AI Request", self)
        status_button = QtWidgets.QPushButton("YiACAD Status", self)
        artifacts_button = QtWidgets.QPushButton("Open Artifacts", self)
        close_button = QtWidgets.QPushButton("Close", self)

        queue_button.clicked.connect(self.on_queue)
        status_button.clicked.connect(lambda: show_status_message())
        artifacts_button.clicked.connect(lambda: open_artifacts())
        close_button.clicked.connect(self.close)

        for button in (queue_button, status_button, artifacts_button, close_button):
            button_row.addWidget(button)

        layout.addLayout(button_row)

    def on_queue(self) -> None:
        payload = run_bridge(
            [
                "request",
                "--surface",
                "freecad",
                "--intent",
                self.intent.currentText(),
                "--prompt",
                self.prompt.toPlainText().strip(),
                "--source-path",
                self.source.text().strip(),
                "--selection-json",
                json.dumps(selection_summary(), ensure_ascii=True),
            ]
        )
        QtWidgets.QMessageBox.information(
            self,
            "YiACAD",
            f"Queued request:\n{payload.get('request_path', '')}",
        )


def show_dialog() -> None:
    dialog = YiACADDialog()
    dialog.exec_()
