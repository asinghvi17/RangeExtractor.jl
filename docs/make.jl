using TiledExtractor
using Documenter

DocMeta.setdocmeta!(TiledExtractor, :DocTestSetup, :(using TiledExtractor); recursive=true)

makedocs(;
    modules=[TiledExtractor],
    authors="Anshul Singhvi <anshulsinghvi@gmail.com> and contributors",
    sitename="TiledExtractor.jl",
    format=Documenter.HTML(;
        canonical="https://JuliaGeo.github.io/TiledExtractor.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/JuliaGeo/TiledExtractor.jl",
    devbranch="main",
)
