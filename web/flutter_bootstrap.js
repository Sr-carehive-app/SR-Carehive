{{flutter_js}}
{{flutter_build_config}}

// ROOT CAUSE FIX: The buildConfig above hardcodes renderer:"canvaskit".
// CanvasKit fetches fonts from fonts.gstatic.com at runtime → ERR_CONNECTION_CLOSED → blank icons.
// Passing config:{renderer:"html"} makes FlutterLoader.load() pick the {} build entry
// (which has no renderer constraint), forcing HTML renderer.
// HTML renderer uses browser CSS/DOM font stack → our bundled fonts work correctly.
_flutter.loader.load({
  config: {
    renderer: "html",
  },
});
