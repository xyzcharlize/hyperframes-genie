// Two video plans for one story. Preview stays local. Production is HeyGen.

class PreviewPlan {
    title: string,
    slug: string,
    aspect: Aspect,
    palette: Palette,
    beats: Beat[],
    script: string @description("words the local TTS voice speaks"),
    avatar: "still",
    voice: "local-tts",
    voice_id: string @description("Kokoro voice id, default af_heart"),
    still: string @description("still avatar path, relative to the video folder"),
}

class ProductionPlan {
    title: string,
    slug: string,
    aspect: Aspect,
    palette: Palette,
    beats: Beat[],
    script: string @description("words the HeyGen avatar lip-syncs"),
    avatar: "heygen-lipsync",
    voice: "heygen",
    avatar_id: string @description("HeyGen avatar id; empty until a person chooses one"),
    voice_id: string @description("speaking voice; often not the avatar's default voice"),
}

class Approval {
    status: "approved" | "rejected",
    note: string,
    script: string @description("preview script a person reviewed"),
}

function narration_script(beats: Beat[]) -> string {
    beats
        .map((beat) -> {
            beat.body
        })
        .join(" ")
}

function local_voice_id(value: string) -> string {
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

function preview_plan_from_film(
    film: Film,
    voice_id: string = "af_heart",
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
        voice: "local-tts",
        voice_id: local_voice_id(voice_id),
        still: still_path(still),
    }
}

function production_plan_from_film(
    film: Film,
    avatar_id: string = "",
    voice_id: string = "",
) -> ProductionPlan {
    ProductionPlan {
        title: film.title,
        slug: film.slug,
        aspect: aspect_for(film.width, film.height),
        palette: film.palette,
        beats: film.beats,
        script: narration_script(film.beats),
        avatar: "heygen-lipsync",
        voice: "heygen",
        avatar_id: heygen_id(avatar_id, "avatar_id"),
        voice_id: heygen_id(voice_id, "voice_id"),
    }
}

// Null when the paid lip-sync is allowed to be considered. It is still not started here.
function production_block(approval: Approval?, plan: ProductionPlan) -> string? {
    //# A person must approve the preview script before HeyGen
    if (approval == null) {
        return "Approve the preview before the HeyGen production cut.";
    }
    if (approval.status != "approved") {
        return "Production cut is blocked because the preview was rejected.";
    }
    if (approval.script != plan.script) {
        return "The story changed after approval. Review the preview again.";
    }
    if (plan.avatar_id == "") {
        return "Production plan needs a HeyGen avatar_id.";
    }
    // Omitting voice_id would let HeyGen speak with the avatar's default voice.
    if (plan.voice_id == "") {
        return "Production plan needs a voice_id. The speaking voice is its own HeyGen id, often not the avatar's default.";
    }
    null
}

// Body for `heygen video create`. voice_id is always set, so the avatar default is not used. Nothing here sends it.
function heygen_request(plan: ProductionPlan) -> string {
    let avatar = baml.json.to_string(plan.avatar_id);
    let voice = baml.json.to_string(plan.voice_id);
    let script = baml.json.to_string(plan.script);
    `{"type":"avatar","avatar_id":${avatar},"voice_id":${voice},"script":${script}}`
}
