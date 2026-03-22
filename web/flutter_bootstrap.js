{{flutter_js}}
{{flutter_build_config}}

// Force HTML renderer so Material Icons (CSS/Google Fonts) render correctly.
// CanvasKit (default) fetches Noto from fonts.gstatic.com at runtime which
// fails in production with ERR_CONNECTION_CLOSED → blank icons.
// HTML renderer uses browser CSS font stack → Google Fonts CDN link works.
_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    let appRunner = await engineInitializer.initializeEngine({
      renderer: "html",
    });
    await appRunner.runApp();
  },
});
