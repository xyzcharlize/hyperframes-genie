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

`baml run main` writes `videos/hyperframes-genie`. To render a plan from Cursor, pass the JSON:

```bash
baml run main -- --plan_file plans/film.json --check true
```

`--plan` accepts the same JSON inline. `--out` is a relative project path. `--check true` runs `npm run check` after writing.

Preview and render from the video directory:

```bash
cd videos/hyperframes-genie
npm run dev
npm run check
npm run render
```

Agent skills for this repo live in `.agents/skills` (Cursor) and `.claude/skills` (Claude Code): `baml-core` plus the HyperFrames pack.
