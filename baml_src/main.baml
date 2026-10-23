// Entry point. Cursor writes the plan; this program only renders it.

function resolve_film(plan: string, plan_file: string) -> Film {
    //# A JSON plan from Cursor. An empty run does not write a video.
    if (plan_file != "") {
        return film_from_json(baml.fs.read(plan_file));
    }
    if (plan != "") {
        return film_from_json(plan);
    }
    throw baml.errors.InvalidArgument { message: "Pass --plan_file videos/<slug>/plan.json." }
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
    //# Write the composition and one silent plan.json
    publish_video(dir, film, check = check, still = still)
}
