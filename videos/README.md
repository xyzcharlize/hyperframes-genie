# videos

One folder per video. One story is saved twice: a preview plan and a production plan. They share the words. The avatar and the voice do not.

```text
videos/
  <slug>/
    plan.json              # FilmPlan story
    preview-plan.json      # still avatar, local Kokoro TTS
    production-plan.json   # HeyGen lip-sync; voice_id is often not the avatar default
    approval.json          # a person's review; not committed
    index.html
    compositions/
    renders/
      preview-cut.mp4     # draft composition for review
```

Render the preview, then HyperFrames Studio opens on that project so a person can make fine adjustments. Approving requires the preview file. Once a production cut exists, Studio is the last step for that file too. Republishing the story deletes the approval, because the approved script no longer matches.
