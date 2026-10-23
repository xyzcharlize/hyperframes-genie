// One story, three stages: silent preview, HeyGen voice, then lip-sync.

class PreviewPlan {
    title: string,
    slug: string,
    aspect: Aspect,
    palette: Palette,
    beats: Beat[],
    script: string @description("words on screen; the preview does not speak them"),
    avatar: "still",
    voice: "silent",
    voice_id: string @description("empty; the preview has no voice"),
    still: string @description("still avatar path, relative to the video folder"),
}

class VoicePlan {
    title: string,
    slug: string,
    aspect: Aspect,
    palette: Palette,
    beats: Beat[],
    script: string @description("same words, now spoken by a HeyGen voice"),
    avatar: "still",
    voice: "heygen",
    voice_id: string @description("HeyGen voice added after the silent preview"),
    still: string,
}

class LipsyncPlan {
    title: string,
    slug: string,
    aspect: Aspect,
    palette: Palette,
    beats: Beat[],
    script: string @description("words the HeyGen avatar lip-syncs"),
    avatar: "heygen-lipsync",
    voice: "heygen",
    avatar_id: string @description("HeyGen avatar id; empty until the voice has been reviewed"),
    voice_id: string @description("the reviewed HeyGen voice, often not the avatar default"),
}

class StageReview {
    status: "approved" | "rejected",
    note: string,
    script: string,
    voice_id: string,
}

class Reviews {
    preview: StageReview?,
    voice: StageReview?,
}

function narration_script(beats: Beat[]) -> string {
    beats
        .map((beat) -> {
            beat.body
        })
        .join(" ")
}

function still_path(value: string) -> string {
    let ok = baml.regex.new("^[A-Za-z0-9._/-]+$").match_full(value) != null;
    if (!ok || value == "" || value.includes("..") || value.starts_with("/")) {
        "assets/avatar-still.png"
    } else {
        value
    }
}

function heygen_id(value: string, label: string) -> string {
    if (baml.regex.new("^[A-Za-z0-9_-]*$").match_full(value) == null) {
        throw baml.errors.InvalidArgument { message: `${label} must be a HeyGen id` }
    }
    value
}

function preview_plan_from_film(
    film: Film,
    still: string = "assets/avatar-still.png",
) -> PreviewPlan {
    PreviewPlan {
        title: film.title,
        slug: film.slug,
        aspect: aspect_for(film.width, film.height),
        palette: film.palette,
        beats: film.beats,
        script: narration_script(film.beats),
        avatar: "still",
        voice: "silent",
        voice_id: "",
        still: still_path(still),
    }
}

function voice_plan_from_preview(preview: PreviewPlan, voice_id: string) -> VoicePlan {
    VoicePlan {
        title: preview.title,
        slug: preview.slug,
        aspect: preview.aspect,
        palette: preview.palette,
        beats: preview.beats,
        script: preview.script,
        avatar: "still",
        voice: "heygen",
        voice_id: heygen_id(voice_id, "voice_id"),
        still: preview.still,
    }
}

function empty_voice_plan(film: Film, still: string = "assets/avatar-still.png") -> VoicePlan {
    let preview = preview_plan_from_film(film, still = still);
    VoicePlan {
        title: preview.title,
        slug: preview.slug,
        aspect: preview.aspect,
        palette: preview.palette,
        beats: preview.beats,
        script: preview.script,
        avatar: "still",
        voice: "heygen",
        voice_id: "",
        still: preview.still,
    }
}

function lipsync_plan_from_voice(voice: VoicePlan, avatar_id: string) -> LipsyncPlan {
    LipsyncPlan {
        title: voice.title,
        slug: voice.slug,
        aspect: voice.aspect,
        palette: voice.palette,
        beats: voice.beats,
        script: voice.script,
        avatar: "heygen-lipsync",
        voice: "heygen",
        avatar_id: heygen_id(avatar_id, "avatar_id"),
        voice_id: voice.voice_id,
    }
}

function empty_lipsync_plan(film: Film) -> LipsyncPlan {
    let voice = empty_voice_plan(film);
    LipsyncPlan {
        title: voice.title,
        slug: voice.slug,
        aspect: voice.aspect,
        palette: voice.palette,
        beats: voice.beats,
        script: voice.script,
        avatar: "heygen-lipsync",
        voice: "heygen",
        avatar_id: "",
        voice_id: "",
    }
}

// The local preview must be approved in Studio before the voice changes.
function voice_swap_block(review: StageReview?, script: string, voice_id: string) -> string? {
    if (review == null) {
        return "Review the preview in Studio before swapping the voice.";
    }
    if (review.status != "approved") {
        return "Voice swap is blocked because the preview was rejected.";
    }
    if (review.script != script) {
        return "The story changed after the preview review. Review it in Studio again.";
    }
    if (voice_id == "") {
        return "Name the HeyGen voice_id. The preview is silent, and this voice is often not an avatar's default voice.";
    }
    null
}

// The HeyGen voice must be approved in Studio before the lip-sync avatar is added.
function lipsync_block(review: StageReview?, plan: LipsyncPlan) -> string? {
    if (review == null) {
        return "Review the HeyGen voice in Studio before adding the lip-sync avatar.";
    }
    if (review.status != "approved") {
        return "Lip-sync is blocked because the HeyGen voice was rejected.";
    }
    if (review.script != plan.script) {
        return "The story changed after the voice review. Review it in Studio again.";
    }
    if (plan.voice_id == "" || plan.voice_id != review.voice_id) {
        return "The lip-sync must use the HeyGen voice that was reviewed.";
    }
    if (plan.avatar_id == "") {
        return "Name the HeyGen avatar_id. The speaking voice stays the reviewed voice_id.";
    }
    null
}

// Body for a later `heygen video create`. voice_id is the reviewed voice. Nothing here sends it.
function heygen_request(plan: LipsyncPlan) -> string {
    let avatar = baml.json.to_string(plan.avatar_id);
    let voice = baml.json.to_string(plan.voice_id);
    let script = baml.json.to_string(plan.script);
    `{"type":"avatar","avatar_id":${avatar},"voice_id":${voice},"script":${script}}`
}
