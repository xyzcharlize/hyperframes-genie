// Entry point: a brief becomes a HyperFrames project on disk.

function main(brief: string = "", out: string = "", check: bool = false) -> string {
    //# Plan from the brief, or use the built-in demo when it is empty
    let film = if (brief == "") {
        demo_film()
    } else {
        normalize(plan_film(brief))
    };
    let dir = if (out == "") {
        `videos/${film.slug}`
    } else {
        out
    };
    //# Write index.html and one composition per scene
    write_project(dir, film, check = check)
}
