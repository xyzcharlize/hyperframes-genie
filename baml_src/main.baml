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
) -> string {
    let film = resolve_film(plan, plan_file);
    let dir = if (out == "") {
        `videos/${film.slug}`
    } else {
        out
    };
    //# Write index.html and one composition per scene
    write_project(dir, film, check = check)
}
