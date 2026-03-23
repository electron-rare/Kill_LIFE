from __future__ import annotations

import os

import FreeCADGui  # type: ignore

from . import yiacad_freecad_gui


class _OpenPanelCommand:
    def GetResources(self):
        return {
            "MenuText": "YiACAD AI Panel",
            "ToolTip": "Open the YiACAD AI dialog for FreeCAD",
            "Pixmap": os.path.join(os.path.dirname(__file__), "Resources", "icons", "yiacad_ai.svg"),
        }

    def Activated(self):
        yiacad_freecad_gui.show_dialog()

    def IsActive(self):
        return True


class _StatusCommand:
    def GetResources(self):
        return {
            "MenuText": "YiACAD Status",
            "ToolTip": "Show the latest YiACAD status snapshot",
            "Pixmap": os.path.join(os.path.dirname(__file__), "Resources", "icons", "yiacad_ai.svg"),
        }

    def Activated(self):
        yiacad_freecad_gui.show_status_message()

    def IsActive(self):
        return True


class _ArtifactsCommand:
    def GetResources(self):
        return {
            "MenuText": "YiACAD Artifacts",
            "ToolTip": "Open the local Kill_LIFE artifacts folder",
            "Pixmap": os.path.join(os.path.dirname(__file__), "Resources", "icons", "yiacad_ai.svg"),
        }

    def Activated(self):
        yiacad_freecad_gui.open_artifacts()

    def IsActive(self):
        return True


class YiACADWorkbench(FreeCADGui.Workbench):  # type: ignore[misc]
    MenuText = "YiACAD AI"
    ToolTip = "AI-native CAD utilities for FreeCAD linked to Kill_LIFE"
    Icon = os.path.join(os.path.dirname(__file__), "Resources", "icons", "yiacad_ai.svg")

    def Initialize(self):
        FreeCADGui.addCommand("YiACAD_OpenPanel", _OpenPanelCommand())
        FreeCADGui.addCommand("YiACAD_Status", _StatusCommand())
        FreeCADGui.addCommand("YiACAD_Artifacts", _ArtifactsCommand())
        self.appendToolbar("YiACAD AI", ["YiACAD_OpenPanel", "YiACAD_Status", "YiACAD_Artifacts"])
        self.appendMenu("YiACAD AI", ["YiACAD_OpenPanel", "YiACAD_Status", "YiACAD_Artifacts"])

    def GetClassName(self):
        return "Gui::PythonWorkbench"


FreeCADGui.addWorkbench(YiACADWorkbench())
