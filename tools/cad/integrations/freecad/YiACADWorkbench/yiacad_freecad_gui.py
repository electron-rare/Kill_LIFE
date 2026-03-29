from __future__ import annotations

import json
import subprocess

try:
    import FreeCAD  # type: ignore
except Exception:  # pragma: no cover
    FreeCAD = None

try:
    import FreeCADGui  # type: ignore
except Exception:  # pragma: no cover
    FreeCADGui = None

try:
    from PySide2 import QtWidgets  # type: ignore
except Exception:  # pragma: no cover
    try:
        from PySide import QtGui as QtWidgets  # type: ignore
    except Exception:  # pragma: no cover
        QtWidgets = None

from ._adapter import available_registry_actions, current_document_path, selection_summary
from ._common import (
    append_session_message,
    backend_client_script,
    clear_session,
    fetch_status_payload,
    load_session,
    open_path,
    remember_session_state,
    repo_root,
    run_intent,
)


ACTION_ENTRIES = [entry for entry in available_registry_actions() if entry["transport_command"] != "status"]


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


def run_native_json_action(command: str, *args: str) -> dict:
    proc = subprocess.run(
        ["python3", str(backend_client_script()), "--surface", "yiacad-desktop", "--json-output", command, *args],
        cwd=repo_root(),
        text=True,
        capture_output=True,
        check=False,
        timeout=30,
    )
    if proc.returncode != 0 and not proc.stdout.strip():
        raise RuntimeError(proc.stderr.strip() or "YiACAD backend client failed")
    return json.loads(proc.stdout.strip() or "{}")


def show_status_message() -> None:
    if QtWidgets is None:
        raise RuntimeError("QtWidgets is unavailable in the current FreeCAD runtime")
    payload = fetch_status_payload(current_document_path(FreeCAD))
    QtWidgets.QMessageBox.information(None, "YiACAD Status", _result_message(payload))


def open_artifacts() -> None:
    open_path(repo_root() / "artifacts")


if QtWidgets is not None:

    class YiACADDialog(QtWidgets.QDialog):
        def __init__(self) -> None:
            super().__init__(None)
            self.setWindowTitle("YiACAD AI for FreeCAD")
            self.resize(720, 560)

            layout = QtWidgets.QVBoxLayout(self)
            session = load_session()
            default_source = current_document_path(FreeCAD) or session.get("last_source_path") or ""
            self.actions = list(ACTION_ENTRIES)

            self.intent = QtWidgets.QComboBox(self)
            self.intent.addItems([entry["display_name"] for entry in self.actions])
            commands = [entry["transport_command"] for entry in self.actions]
            if session.get("last_intent") in commands:
                self.intent.setCurrentIndex(commands.index(session["last_intent"]))
            elif self.actions:
                self.intent.setCurrentIndex(0)

            self.source = QtWidgets.QLineEdit(self)
            self.source.setReadOnly(True)
            self.source.setText(default_source)
            self.prompt = QtWidgets.QPlainTextEdit(self)
            self.prompt.setPlainText(
                session.get("last_prompt") or "Describe the FreeCAD task context for YiACAD. The action run remains deterministic."
            )
            self.transcript = QtWidgets.QPlainTextEdit(self)
            self.transcript.setReadOnly(True)
            self.refresh_transcript()

            layout.addWidget(QtWidgets.QLabel("Action", self))
            layout.addWidget(self.intent)
            layout.addWidget(QtWidgets.QLabel("Document / source path", self))
            layout.addWidget(self.source)
            layout.addWidget(QtWidgets.QLabel("Transcript", self))
            layout.addWidget(self.transcript)
            layout.addWidget(QtWidgets.QLabel("Task context", self))
            layout.addWidget(self.prompt)

            button_row = QtWidgets.QHBoxLayout()
            run_button = QtWidgets.QPushButton("Run YiACAD Action", self)
            status_button = QtWidgets.QPushButton("YiACAD Status", self)
            artifacts_button = QtWidgets.QPushButton("Open Artifacts", self)
            clear_button = QtWidgets.QPushButton("Clear Session", self)
            close_button = QtWidgets.QPushButton("Close", self)

            run_button.clicked.connect(self.on_run)
            status_button.clicked.connect(self.on_status)
            artifacts_button.clicked.connect(self.on_artifacts)
            clear_button.clicked.connect(self.on_clear)
            close_button.clicked.connect(self.close)

            for button in (run_button, status_button, artifacts_button, clear_button, close_button):
                button_row.addWidget(button)

            layout.addLayout(button_row)

        def persist_state(self) -> None:
            command = self.actions[self.intent.currentIndex()]["transport_command"]
            remember_session_state(
                command,
                self.prompt.toPlainText().strip(),
                self.source.text().strip(),
            )

        def refresh_transcript(self) -> None:
            self.transcript.setPlainText(_transcript_text(load_session()))
            cursor = self.transcript.textCursor()
            cursor.movePosition(cursor.End)
            self.transcript.setTextCursor(cursor)

        def on_run(self) -> None:
            if not self.actions:
                return
            prompt = self.prompt.toPlainText().strip()
            source_path = self.source.text().strip()
            command = self.actions[self.intent.currentIndex()]["transport_command"]
            self.persist_state()
            append_session_message(
                "user",
                prompt or "(no additional task context provided)",
                intent=command,
                source_path=source_path,
            )
            payload = run_intent(
                "yiacad-desktop",
                command,
                prompt,
                source_path,
                selection_summary(FreeCADGui),
            )
            result_text = _result_message(payload)
            append_session_message(
                "assistant",
                result_text,
                intent=command,
                source_path=source_path,
                status=str(payload.get("status") or ""),
            )
            self.refresh_transcript()
            QtWidgets.QMessageBox.information(self, "YiACAD", result_text)

        def on_status(self) -> None:
            source_path = self.source.text().strip()
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
            QtWidgets.QMessageBox.information(self, "YiACAD Status", result_text)

        def on_artifacts(self) -> None:
            self.persist_state()
            open_artifacts()

        def on_clear(self) -> None:
            clear_session()
            self.refresh_transcript()

else:

    class YiACADDialog:  # pragma: no cover
        def exec_(self) -> None:
            raise RuntimeError("QtWidgets is unavailable in the current FreeCAD runtime")


def show_dialog() -> None:
    dialog = YiACADDialog()
    dialog.exec_()
