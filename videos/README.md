# videos

One folder per video. One `plan.json`. Studio is the review between the silent preview, the HeyGen voice, and the lip-sync avatar.

```text
videos/
  <slug>/
    plan.json            # story; voice_id and avatar_id start empty
    trace.json           # the stage path that produced this film
    reviews.json         # preview review, then voice review; not committed
    index.html
    compositions/
    renders/
      preview-cut.mp4   # the only local render
```

Order: render the silent preview, review it in Studio, add the HeyGen voice, review that in Studio, then add the lip-sync avatar. Republishing the story deletes the reviews.
