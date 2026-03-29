from __future__ import annotations

from ._common import available_actions


def current_document_path(freecad_module=None) -> str:
    if freecad_module is None:
        return ""
    document = getattr(freecad_module, "ActiveDocument", None)
    if document is None:
        return ""
    return str(getattr(document, "FileName", "") or "")


def selection_summary(freecad_gui_module=None) -> list[str]:
    if freecad_gui_module is None:
        return []
    try:
        selected = []
        for item in freecad_gui_module.Selection.getSelectionEx():
            object_name = getattr(item, "ObjectName", None)
            if object_name:
                selected.append(str(object_name))
        return selected
    except Exception:
        return []


def available_registry_actions() -> list[dict]:
    return list(available_actions())
