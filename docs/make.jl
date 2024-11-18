using RangeExtractor
using Documenter

DocMeta.setdocmeta!(RangeExtractor, :DocTestSetup, :(using RangeExtractor); recursive=true)

makedocs(;
    modules=[RangeExtractor],
    authors="Anshul Singhvi <anshulsinghvi@gmail.com>, Alex Gardner <alex.s.gardner@jpl.nasa.gov>, and contributors",
    sitename="RangeExtractor.jl",
    format=Documenter.HTML(;
        canonical="https://asinghvi17.github.io/RangeExtractor.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        # "Examples"
        "Operations" => "operations.md",
        "Tiling Strategies" => "tilingstrategy.md",
        "Developer Documentation" => "devdocs.md",
        "API" => "api.md",
    ],
    warnonly=true,
)

deploydocs(;
    repo="github.com/asinghvi17/RangeExtractor.jl",
    devbranch="main",
)
