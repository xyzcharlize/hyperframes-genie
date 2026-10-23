# videos

One folder per video. One plan.json moves through three stages. Studio is the review between them.

```text
videos/
  <slug>/
    plan.json            # story plus local_voice_id, voice_id, and avatar_id
    reviews.json         # preview review, then voice review; not committed
    index.html
    compositions/
    renders/
      preview-cut.mp4   # the only local render
```

Order: render the preview, review it in Studio, swap the voice from local to HeyGen, review that in Studio, then add the lip-sync avatar. Those later steps fill `voice_id` and `avatar_id` on `plan.json`. Republishing the story rewrites that file and deletes the reviews.
