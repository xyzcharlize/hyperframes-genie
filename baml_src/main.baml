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
    still: string = "assets/avatar-still.png",
) -> string {
    let film = resolve_film(plan, plan_file);
    let dir = if (out == "") {
        video_paths(film.slug).root
    } else {
        out
    };
    //# Write the composition, the silent preview, and empty HeyGen stages
    publish_video(dir, film, check = check, still = still)
}
