# videos

One folder per video. Several renders of that video live side by side and do not overwrite each other.

```text
videos/
  <slug>/
    plan.json          # FilmPlan used to build the composition
    index.html         # HyperFrames root
    compositions/      # one file per scene
    renders/
      draft.mp4
      looks.mp4
      delivery.mp4
```

`draft`, `looks`, and `delivery` are the HyperFrames quality presets. Any other take name is another file in the same `renders/` directory.
