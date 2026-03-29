from .yiacad_action import YiACADActionPlugin

plugin = YiACADActionPlugin()
if hasattr(plugin, "register"):
    plugin.register()
