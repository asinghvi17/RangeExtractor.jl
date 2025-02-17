using Extents

xs = 0:10:40
ys = 0:10:40
exts = [Extent(X = X, Y = Y) for X in zip(xs[1:end-1], xs[2:end]), Y in zip(ys[1:end-1], ys[2:end])]

ras = Raster(zeros(Int, X(0:40), Y(0:40)))

for ext in exts
    ras[ext] .+= 1
end

fig, ax, plt = heatmap(0..40, 0..40, ras.data; colorrange = (0, 4), axis = (; title = "Tiles needed for stencil operation"))

leg = Legend(
    fig[1, 2],
    [PolyElement(color = cgrad(plt.colormap[])[i / 4]) for i in [1, 2, 4]],
    ["1 tile needed", "2 tiles needed", "4 tiles needed"],
)

fig