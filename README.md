# hyperframes-genie

Cursor plans the film with the model on your subscription. BAML turns that plan into a HyperFrames project. No API key.

The plan is a `FilmPlan` (`baml_src/film.baml`): scenes, copy, colors, and timing. Words on screen only, three or four scenes, each 3 to 5 seconds, total under 15 seconds. An empty run writes the built-in demo and does not ask a model for anything.

## Run

Install the BAML CLI once (`curl -fsSL https://pkg.boundaryml.com/install.sh | sh -s`), then:

```bash
export PATH="$HOME/.baml/bin:$PATH"

baml test
baml run main
```

Each video is one folder. The plan and the composition sit at its root. Render the preview-cut first and the production-cut second. Those two files sit under `renders/`:

```text
videos/
  <slug>/
    plan.json
    index.html
    compositions/
    renders/
      preview-cut.mp4
      production-cut.mp4
```

`baml run main` writes `videos/hyperframes-genie`. To render a plan from Cursor, pass the JSON. `--plan` accepts the same JSON inline. `--out` is the video folder. `--check true` runs `npm run check` after writing.

```bash
baml run main -- --plan_file videos/ceramic-studio/plan.json --check true
```

Render the preview-cut first, then the production-cut. Preview-cut uses HyperFrames quality `draft` and writes `renders/preview-cut.mp4`. Production-cut uses quality `delivery` and writes `renders/production-cut.mp4`. An extra take still goes through `render_take`. Preview the composition from the video directory:

```bash
baml run render_cut -- --dir videos/hyperframes-genie --cut preview
baml run render_cut -- --dir videos/hyperframes-genie --cut production
baml run render_take -- --dir videos/hyperframes-genie --quality looks --take looks

cd videos/hyperframes-genie
npm run dev
npm run check
```

Agent skills for this repo live in `.agents/skills`: `baml-core` plus the HyperFrames pack.
