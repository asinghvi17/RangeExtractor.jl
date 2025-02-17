using Geodesy, Rasters, ArchGDAL
using Stencils
using LinearAlgebra, Statistics, StaticArrays, OhMyThreads

using NonlinearSolve # till I figure out a better least squares solver

const ns = Stencils.Window(1, 2)
const WGS84_LLA_TO_ECEF = Geodesy.ECEFfromLLA(Geodesy.wgs84)
const WGS84_ELLPS = Geodesy.wgs84 |> Geodesy.ellipsoid


_latlong_and_val_to_ecef((long, lat), val) = WGS84_LLA_TO_ECEF(LLA(lat, long, val))

function geodesic_aspect_kernel(stencil_vals, stencil_points)
    # Convert long-lat-alt to ECEF
    stencil_points_ECEF = _latlong_and_val_to_ecef.(stencil_points, stencil_vals)

    e,n,u = local_tangent_axes(WGS84_ELLPS, stencil_points.center...)

    # Fit the plane to the points
    surface_normal = best_normal(stencil_points_ECEF)

    # Get the lat/long of the center of the stencil
    return aspect_of_normal_on_ellipsoid(WGS84_ELLPS, surface_normal, (e, n, u))
end

function best_normal(ecefs)
    centered = ecefs .- (mean(ecefs),)
    U, Σ, V = svd(
        SMatrix{3, 9, Float64}(reinterpret(reshape, Float64, centered)))
    col = argmin(Σ)
    return SVector{3, Float64}(U[1, col], U[2, col], U[3, col])
end

# ellipsoid utils


# -------------------------------------------------------------------------
# Aspect angle on ellipsoid:
#   1) project the surface normal onto local tangent plane
#   2) measure clockwise angle from north to that projection
# -------------------------------------------------------------------------
function aspect_of_normal_on_ellipsoid(ellip::Ellipsoid,
    surface_normal::SVector{3, Float64},
    lon::Float64,
    lat::Float64
)
    aspect = aspect_of_normal_on_ellipsoid(ellip, surface_normal, local_tangent_axes(ellip, lon, lat))
end
function aspect_of_normal_on_ellipsoid(ellip::Ellipsoid,
    surface_normal::SVector{3, Float64},
    (e, n, u)::NTuple{3, SVector{3, Float64}}
    )
    # If the fitted plane normal is pointing "down" instead of "up",
    # you might want to ensure it's oriented outward:
    if dot(surface_normal, u) < 0
        surface_normal = -surface_normal
    end

    # Project onto tangent plane
    #   plane normal = u
    #   projection = s - (s·u)*u
    s_proj = surface_normal .- (dot(surface_normal, u) .* u)

    # "aspect" is angle from north to s_proj, going clockwise
    # We'll do: α = atan2( dot(s_proj, e), dot(s_proj, n) )
    x = dot(s_proj, e)
    y = dot(s_proj, n)
    α_rad = atan(y, x)

    # Convert to [0, 360)
    α_deg = mod(α_rad * 180/π, 360)
    return α_deg
end


# -------------------------------------------------------------------------
# Ellipsoid normal in ECEF
# Given geodetic lat/long (in radians), returns the outward unit normal
# of the reference ellipsoid at that lat/long.
# -------------------------------------------------------------------------
function ellipsoid_normal(ellip::Geodesy.Ellipsoid, lon::Float64, lat::Float64)
    sinφ, cosφ = sind(lat), cosd(lat)
    sinλ, cosλ = sind(lon), cosd(lon)

    a, b, e2 = ellip.a, ellip.b, ellip.e2

    # Radius of curvature in the prime vertical
    N = a / sqrt(1.0 - e2*sinφ^2)

    # ECEF coordinates of that lat/lon on the ellipsoid surface (height=0)
    X = N * cosφ * cosλ
    Y = N * cosφ * sinλ
    Z = N * (1.0 - e2) * sinφ   # equivalently b^2/a^2 * N * sinφ

    # Compute outward normal ∝ (X/a^2, Y/a^2, Z/b^2), then normalize
    Nx = X / (a^2)
    Ny = Y / (a^2)
    Nz = Z / (b^2)
    n_unnorm = SVector{3, Float64}(Nx, Ny, Nz)

    return n_unnorm / norm(n_unnorm)
end


# -------------------------------------------------------------------------
# Local tangent axes in ECEF for lat/long on the ellipsoid:
#   - up    (u) = ellipsoid normal (unit vector)
#   - east  (e) = derivative wrt longitude, orthonormalized vs. up
#   - north (n) = up × east
#
# The resulting (e, n, u) is a right-handed coordinate system
# tangent to the ellipsoid at lat/lon.
# -------------------------------------------------------------------------
function local_tangent_axes(ellip::Geodesy.Ellipsoid, lon::Float64, lat::Float64)
    sinφ, cosφ = sind(lat), cosd(lat)
    sinλ, cosλ = sind(lon), cosd(lon)

    # Up (unit normal)
    u = ellipsoid_normal(ellip, lat, lon)

    # For height=0, the partial derivative wrt λ (longitude) at lat, lon is:
    #   dX/dλ = -N cosφ sinλ
    #   dY/dλ =  N cosφ cosλ
    #   dZ/dλ =  0
    # where N = a / sqrt(1 - e2 sin^2 φ). We'll just re-derive that N:
    N = ellip.a / sqrt(1 - ellip.e2*sinφ^2)

    # This vector points "roughly East", but not orthonormal to u yet
    e_candidate = SVector{3, Float64}(
        -N * cosφ * sinλ,
         N * cosφ * cosλ,
         0.0
    )

    # Project out any component along u, then normalize
    e_ortho = e_candidate - (dot(e_candidate, u) * u)
    e = e_ortho / norm(e_ortho)

    # North = up × east
    n = cross(u, e)
    # (u, e, n) is right-handed, but to keep consistent ordering "East, North, Up"
    # we return (e, n, u).
    return (e, n, u)
end



# function _fit_value(current_normal, centered_ecefs)
#     return sum(abs.(dot.((current_normal,), centered_ecefs)))
# end

# ecefs = [WGS84_LLA_TO_ECEF(LLA(0, lon)) for lon in -90:20:90] |> SVector{10}
# LSQ_PROBLEM = NonlinearSolve.NonlinearLeastSquaresProblem(
#     _fit_value, # f
#     SVector{3, Float64}(0, 0. + eps(), 1) |> collect; # u0
#     p = ecefs .|> collect # p
# )

using Rasters

ras = Raster("/Volumes/Anshul's Passport/Copernicus-30m/Copernicus_DSM_COG_10_N00_00_E006_00_DEM/Copernicus_DSM_COG_10_N00_00_E006_00_DEM.tif")

a1 = StencilArray(ras, ns; boundary = Use(), padding = Halo(:in))
a2 = StencilArray(DimPoints(ras), ns; boundary = Use(), padding = Halo(:in))

geodesic_aspect_kernel(stencil(a1, (3, 3)), stencil(a2, (3, 3)))

mapstencil(geodesic_aspect_kernel, a1, a2)

valsandpoints = DimStack((; value = ras, point = DimPoints(ras))) |> collect


sa1 = StencilArray(DimStack((; value = ras, point = DimPoints(ras))), ns; boundary = Use(), padding = Halo(:in))
mapstencil(geodesic_aspect_kernel, ns, ; )

result = @time map(CartesianIndices(a1)) do I
    geodesic_aspect_kernel(stencil(a1, I.I), stencil(a2, I.I))
end


Base.@constprop :aggressive function _do_aspect(ras::R; parallel = true) where R <: Raster

    ns = Stencils.Window(1, 2)

    points = DimPoints(ras)
    a1 = StencilArray(ras, ns; boundary = Use(), padding = Halo(:in))
    a2 = StencilArray(points, ns; boundary = Use(), padding = Halo(:in))

    result = if parallel
        OhMyThreads.tmap(CartesianIndices(a1)) do I
            geodesic_aspect_kernel(stencil(a1, I.I), stencil(a2, I.I))
        end
    else
        map(CartesianIndices(a1)) do I
            geodesic_aspect_kernel(stencil(a1, I.I), stencil(a2, I.I))
        end
    end

    return Raster(
        result,
        (x -> x[2:end-1]).(dims(ras)) # shrink result dims so that we have the dims that we operated on - hack against what Stencils does,
        tuple(),
        :aspect,
        Rasters.metadata(ras),
        Rasters.missingval(ras)
    )
end

using NaturalEarth

all_countries = NaturalEarth.naturalearth("admin_0_countries", 10)

greenland = all_countries.geometry[findfirst(==("Greenland"), all_countries.NAME)]
# Greenland covers about 663 tiles, or 34 GB of tiles _compressed_.
# No way we can load that in RAM (although it's a more tractable problem than I thought.)

using RangeExtractor

fa = Raster(FillArrays.Ones(450000, 450000), (X(LinRange(-180, 180, 450000)), Y(LinRange(-90, 90, 450000))))

zonal(RangeExtractor.SumTileOperation(), fa, RangeExtractor.FixedGridTiling{2}(1250); of = [greenland], threaded = RangeExtractor.Serial()) 