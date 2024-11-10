using TiledExtractor
using Documenter

DocMeta.setdocmeta!(TiledExtractor, :DocTestSetup, :(using TiledExtractor); recursive=true)

makedocs(;
    modules=[TiledExtractor],
    authors="Anshul Singhvi <anshulsinghvi@gmail.com>, Alex Gardner <alex.s.gardner@jpl.nasa.gov>, and contributors",
    sitename="TiledExtractor.jl",
    format=Documenter.HTML(;
        canonical="https://asinghvi17.github.io/TiledExtractor.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Developer Documentation" => "devdocs.md",
    ],
)

deploydocs(;
    repo="github.com/asinghvi17/TiledExtractor.jl",
    devbranch="main",
)
