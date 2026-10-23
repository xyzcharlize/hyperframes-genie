// One plan.json per video. voice_id, then avatar_id, fill in after each Studio review.

class VideoPlan {
    title: string,
    slug: string,
    aspect: Aspect,
    palette: Palette,
    beats: Beat[],
    script: string @description("words spoken at every stage"),
    still: string @description("still avatar path, relative to the video folder"),
    local_voice_id: string @description("Kokoro voice id for the preview, default af_heart"),
    voice_id: string @description("HeyGen voice, empty until the preview is reviewed"),
    avatar_id: string @description("HeyGen lip-sync avatar, empty until the voice is reviewed"),
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

function safe_local_voice(value: string) -> string {
    if (baml.regex.new("^[a-z0-9_]+$").match_full(value) == null) {
        "af_heart"
    } else {
        value
    }
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

function video_plan_from_film(
    film: Film,
    local_voice: string = "af_heart",
    still: string = "assets/avatar-still.png",
) -> VideoPlan {
    VideoPlan {
        title: film.title,
        slug: film.slug,
        aspect: aspect_for(film.width, film.height),
        palette: film.palette,
        beats: film.beats,
        script: narration_script(film.beats),
        still: still_path(still),
        local_voice_id: safe_local_voice(local_voice),
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
        return "Name the HeyGen voice_id. It replaces the local voice and is often not an avatar's default voice.";
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
