# videos

One folder per video. Render the preview-cut first and the production-cut second. The two files sit side by side and do not overwrite each other.

```text
videos/
  <slug>/
    plan.json             # FilmPlan used to build the composition
    index.html            # HyperFrames root
    compositions/         # one file per scene
    renders/
      preview-cut.mp4     # HyperFrames quality draft
      production-cut.mp4  # HyperFrames quality delivery
```

`preview` is HyperFrames quality `draft`. `production` is quality `delivery`. An extra take from `render_take` is another file in the same `renders/` directory.
