from Plugins.Plugin import PluginDescriptor


def main(session, **kwargs):
	pass


def Plugins(**kwargs):
	return [
		PluginDescriptor(
			name="Example",
			description="Plugin di esempio",
			where=[PluginDescriptor.WHERE_PLUGINMENU],
			fnc=main,
		)
	]
