# videos

One folder per video. One story, then three stages. Studio is the review between them.

```text
videos/
  <slug>/
    plan.json            # FilmPlan story
    preview-plan.json    # still avatar, silent
    voice-plan.json      # still avatar, HeyGen voice_id
    lipsync-plan.json    # HeyGen lip-sync using that reviewed voice
    reviews.json         # preview review, then voice review; not committed
    index.html
    compositions/
    renders/
      preview-cut.mp4   # the only local render
```

Order: render the silent preview, review it in Studio, add the HeyGen voice, review that in Studio, then add the lip-sync avatar. Republishing the story deletes the reviews.
