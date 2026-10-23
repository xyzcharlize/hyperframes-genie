// Entry point. Cursor writes the plan; this program only renders it.

function resolve_film(plan: string, plan_file: string) -> Film {
    //# A JSON plan from Cursor, or the built-in demo when both are empty
    if (plan_file != "") {
        return film_from_json(baml.fs.read(plan_file));
    }
    if (plan != "") {
        return film_from_json(plan);
    }
    demo_film()
}

function main(
    plan: string = "",
    plan_file: string = "",
    out: string = "",
    check: bool = false,
    local_voice: string = "af_heart",
    still: string = "assets/avatar-still.png",
    avatar_id: string = "",
    heygen_voice: string = "",
) -> string {
    let film = resolve_film(plan, plan_file);
    let dir = if (out == "") {
        video_paths(film.slug).root
    } else {
        out
    };
    //# Write the composition plus the preview and production plans
    publish_video(
        dir,
        film,
        check = check,
        local_voice = local_voice,
        still = still,
        avatar_id = avatar_id,
        heygen_voice = heygen_voice,
    )
}
