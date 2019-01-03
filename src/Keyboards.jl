module Keyboards

using Parameters

using Unitful
import Unitful: Length

using Circuits
using Circuits.TikZ
using TikzPictures
const preamble = read(joinpath(dirname(@__FILE__), "preamble.tex"), String)

using PCBs

include("design.jl")
include("circuits.jl")

end # module
