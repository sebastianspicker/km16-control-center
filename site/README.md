# Browser demo

[Open the demo](https://sebastianspicker.github.io/km16-control-center/).

An interactive mockup of KM16 Control Center for GitHub Pages. Choose a factory
profile, select a key or dial action, inspect its assignment, and preview it.
The demo uses the same preset data as the Mac app.

All interactions are simulations. The page cannot send keyboard input, run
commands, connect to OBS or Codex, or read a KM16 pad. Edits last only for the
current page session. Use the native app for desktop actions and saved profiles.

## Run locally

From the repository root, with Python 3.10 or newer installed:

```sh
python3 scripts/build-site.py
python3 -m http.server 8000 --bind 127.0.0.1 --directory dist/site
```

Open <http://127.0.0.1:8000>. Serve the built folder over HTTP; opening `index.html`
as a local file does not allow the page to load its preset JSON reliably.

The site has no package installation or bundler step. `build-site.py` copies only
`index.html`, `styles.css`, `app.js`, `favicon.svg`, and `presets/all.json` (as
`presets.json`), then adds `.nojekyll`. Research files and the rest of the checkout are not part of
the Pages artifact. If the output folder contains unexpected files, the build
stops; choose a fresh destination with `--output`.

## Publish on GitHub Pages

After pushing the repository to GitHub, open **Settings → Pages** and choose
**GitHub Actions** as the build source. The **Browser demo** workflow builds and
deploys changes from `main`; you can also run it manually from the Actions tab.
Pull requests build and check the demo without deploying it.

The deployment job reports the site's URL in the `github-pages` environment. Add
that URL to the repository's About website field and the root README once the
first deployment succeeds. The site uses relative asset paths and works under a
GitHub Pages project path. Custom domains are optional.

See GitHub's [custom Pages workflow guide](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages)
for repository settings and environment protection requirements.

## Change the demo

Edit the HTML, CSS, and JavaScript in this directory. Change factory assignments
through the [preset source workflow](../CONTRIBUTING.md#compatibility-and-presets);
the site build always takes its data from `presets/all.json`.

Run the focused checks before testing the rendered page:

```sh
node --check site/app.js
python3 -m unittest discover -s scripts/tests -p 'test_site_build.py' -v
python3 scripts/build-site.py
```

Check desktop and narrow layouts, keyboard navigation, profile search, key and
knob selection, edits, Preview, and Reset. Keep simulation labels visible and do
not introduce real desktop or service access into the demo.
