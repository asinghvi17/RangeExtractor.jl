using GLMakie, Tyler, Animations, Interpolations, DataInterpolations

using RangeExtractor
using Rasters, ArchGDAL
using NaturalEarth
import GeoInterface as GI, GeometryOps as GO, LibGEOS as LG

fig = Figure(size = (1600, 900))

ax = Axis(fig[1, 1]; aspect = DataAspect())

ax.title = "Glaciers around the world"

"""
    zoom_into_extent!(ax, extent, factor = 1.0)

Zoom the axis towards the extent `extent`, by a factor (going from 0 to 1).  0 means that there is no zooming, 1 means you go straight to that extent.
"""
function zoom_to_extent!(ax, extent::Extent, factor = 1.0)
    return zoom_to_extent!(ax, ax.finallimits[], Rect2((extent.X[1], extent.Y[1]), (extent.X[2] - extent.X[1], extent.Y[2] - extent.Y[1])), factor)
end


function zoom_to_extent!(ax, current_lims::Rect, target_lims::Extent, factor = 1.0)
    return zoom_to_extent!(ax, current_lims, Rect2((target_lims.X[1], target_lims.Y[1]), (target_lims.X[2] - target_lims.X[1], target_lims.Y[2] - target_lims.Y[1])), factor)
end

zoom_to_extent!(ax, target::Rect, factor = 1.0) = zoom_to_extent!(ax, ax.finallimits[], target, factor)

function zoom_to_extent!(ax, current_lims::Rect, target_lims::Rect2, factor = 1.0)
    # Get current limits
    current_xlims = current_lims.origin[1], current_lims.origin[1] + current_lims.widths[1]
    current_ylims = current_lims.origin[2], current_lims.origin[2] + current_lims.widths[2]

    # Calculate target limits
    target_xlims = target_lims.origin[1], target_lims.origin[1] + target_lims.widths[1]
    target_ylims = target_lims.origin[2], target_lims.origin[2] + target_lims.widths[2]

    # Interpolate between current and target
    new_xmin = current_xlims[1] + (target_xlims[1] - current_xlims[1]) * factor
    new_xmax = current_xlims[2] + (target_xlims[2] - current_xlims[2]) * factor
    new_ymin = current_ylims[1] + (target_ylims[1] - current_ylims[1]) * factor 
    new_ymax = current_ylims[2] + (target_ylims[2] - current_ylims[2]) * factor

    # Set new limits
    xlims!(ax, new_xmin, new_xmax)
    ylims!(ax, new_ymin, new_ymax)
end



fig = Figure()
ax = Axis(fig[1, 1]; aspect = DataAspect())

record(fig, "zoom.mp4", LinRange(0, 1, 120)) do i
    zoom_to_extent!(ax, Rect2((0,0), (10,10)),Rect2((0,1), (1,1)), i)
end



