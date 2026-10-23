// One plan.json per video. The preview is silent. voice_id, then avatar_id, fill in after each Studio review.

class VideoPlan {
    title: string,
    slug: string,
    aspect: Aspect,
    palette: Palette,
    beats: Beat[],
    script: string @description("words on screen; the preview does not speak them"),
    still: string @description("still avatar path, relative to the video folder"),
    voice_id: string @description("empty while the preview is silent; HeyGen voice after that review"),
    avatar_id: string @description(
        "empty while the avatar is a still; HeyGen lip-sync avatar after the voice review",
    ),
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

function video_plan_from_film(film: Film, still: string = "assets/avatar-still.png") -> VideoPlan {
    VideoPlan {
        title: film.title,
        slug: film.slug,
        aspect: aspect_for(film.width, film.height),
        palette: film.palette,
        beats: film.beats,
        script: narration_script(film.beats),
        still: still_path(still),
        voice_id: "",
        avatar_id: "",
    }
}

// Keep the still. Record the HeyGen voice and clear any earlier avatar choice.
function with_voice(plan: VideoPlan, voice_id: string) -> VideoPlan {
    VideoPlan { ...plan, voice_id: heygen_id(voice_id, "voice_id"), avatar_id: "" }
}

function with_avatar(plan: VideoPlan, avatar_id: string) -> VideoPlan {
    VideoPlan { ...plan, avatar_id: heygen_id(avatar_id, "avatar_id") }
}

// The silent preview must be approved in Studio before the voice is added.
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
function lipsync_block(review: StageReview?, plan: VideoPlan) -> string? {
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
function heygen_request(plan: VideoPlan) -> string {
    let avatar = baml.json.to_string(plan.avatar_id);
    let voice = baml.json.to_string(plan.voice_id);
    let script = baml.json.to_string(plan.script);
    `{"type":"avatar","avatar_id":${avatar},"voice_id":${voice},"script":${script}}`
}
