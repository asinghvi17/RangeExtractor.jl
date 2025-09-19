struct StencilOperation{ST, F, A} <: RangeExtractor.AbstractTileOperation
    stencil::ST
    f::F
    covarying_arrays::A
end
AbstractTileOperation


function Base.display(::ITerm2Images.ITerm2Display, m::ITerm2Images.MIMEImageType, x::Makie.Figure)
    # Get a string representation of the MIME type
    tp = string(typeof(m).parameters[1])
    @assert typeof(m) == MIME{Symbol(tp)}
    # Convert to that MIME type, and then encode in base64
    im = ITerm2Images.Base64.base64encode(repr(tp, x))
    # Output the image with the right escape sequence, as described on
    # <https://iterm2.com/documentation-images.html>
    sz = length(im)
    w, h = Makie.viewport(x)[].widths
    write(stdout, ITerm2Images.OSC(), "1337;File=[size=$(sz);inline=1;width=$(w)px;height=$(h)px]:", im, ITerm2Images.ST())
    return nothing
end
