# * Key type

mutable struct Key
    legend::String
    width::Float64
    height::Float64
end

function gen_key(args)
    args = split(args, ":")
    legend = get(args, 1, "")
    width = parse(Float64, get(args, 2, "1"))
    height = parse(Float64, get(args, 3, "1"))
    Key(legend, width, height)
end

Base.show(io::IO, key::Key) = write(io, " ", key.legend, " ")

const tikz_legends = Dict("ctrl" => "\$\ue0fb\$",
                          "ret" => "\$\ue0fc\$",
                          "esc" => "\$\ue0fd\$",
                          "cmd" => "\$\ue0fe\$",
                          "tab" => "\$\ue0ff\$",
                          "space" => "\$\ue100\$",
                          "del" => "\$\ue101\$",
                          "alt" => "\$\ue102\$",
                          "option" => "\$\ue103\$",
                          "enter" => "\$\ue105\$",
                          "shift" => "\$\ue106\$",
                          "mod1" => "\$\ue107\$",
                          "mod2" => "\$\ue108\$")

function tikz_legend(legend::String)
    l = get(tikz_legends, legend, legend)
    isascii(l) ? "\\textsf{$l}" : l
end

Base.convert(::Type{TikZnode}, key::Key, U::Length) =
    TikZnode(tikz_legend(key.legend),
             "draw", "rectangle", "rounded corners",
             "minimum width" => key.width*U,
             "minimum height" => key.height*U)

# * Space type

mutable struct Space
    width::Float64
    height::Float64
end

Base.show(io::IO, space::Space) = write(io, "   ")

function gen_space(args)
    args = split(args, ":")
    a,b = (length(args) == 3 || length(args) == 2 && args[1] == "") ? (2,3) : (1,2)
    args[a] == "" && (args[a] = "1")
    width = parse(Float64, get(args, a, "1"))
    height = parse(Float64, get(args, b, "1"))
    Space(width, height)
end

Base.convert(::Type{TikZnode}, space::Space, U::Length) =
    TikZnode("",
             "rectangle", "rounded corners",
             "minimum width" => space.width*U,
             "minimum height" => space.height*U)

# * Row type

const Row = Vector{Union{Key,Space}}

function gen_row(args)
    map(split(args, " ")) do arg
        isempty(arg) || arg[1] == ':' ? gen_space(arg) : gen_key(arg)
    end |> Row
end

# * Keyboard type

mutable struct Keyboard
    rows::Vector{Row}
    U::Length
    clearance::Length
    extra_clearance::Bool
    gravity::Symbol
end
Keyboard(rows::Vector{Row} = Row[]; U::Length = 18u"mm",
         clearance::Length = 0.2u"mm", extra_clearance::Bool = false,
         gravity::Symbol = :nw) =
    Keyboard(rows, U, clearance, extra_clearance, gravity)

function keyboard(fun::Function; kwargs...)
    kbd = Keyboard()
    fun(kbd)
    kbd
end

function nextrow!(kbd::Keyboard)
    push!(kbd.rows, Row())
end

function Base.push!(kbd::Keyboard, key::Union{Key,Space})
    isempty(kbd.rows) && nextrow!(kbd)
    if kbd.extra_clearance
        key.width += kbd.clearance*floor(Int,key.width - 1.0)/kbd.U |> NoUnits
        key.height += kbd.clearance*max(0,floor(Int,key.height - 1.0))/kbd.U |> NoUnits
    end
    push!(kbd.rows[end], key)
end

function Base.push!(kbd::Keyboard, row::Row)
    nextrow!(kbd)
    for key in row
        push!(kbd, key)
    end
end

function Base.show(io::IO, ::MIME"text/plain", kbd::Keyboard)
    for row in kbd.rows
        foreach(k -> show(io, k), row)
        println()
    end
end

# * String macros

macro key_str(args)
    kbd = esc(:kbd)
    quote
        push!($kbd, gen_key($args))
    end
end

macro space_str(args)
    kbd = esc(:kbd)
    quote
        push!($kbd, gen_space($args))
    end
end

macro row_str(args)
    kbd = esc(:kbd)
    row = gen_row(args)
    quote
        push!($kbd.rows, $row)
    end
end

macro keyboard_str(spec)
    rows = map(strip, split(spec, "\n"))
    isempty(last(rows)) && deleteat!(rows, length(rows))
    quote
        keyboard() do kbd
            for row in $rows
                push!(kbd, gen_row(row))
            end
        end
    end
end

# * TikZ conversion

function Base.convert(::Type{TikzPicture}, kbd::Keyboard; kwargs...)
    @unpack U,clearance = kbd
    gravity,direction = if kbd.gravity == :nw
        "north west",1
    else
        "north east",-1
    end
    l = U + clearance
    i = 0
    rows = map(kbd.rows) do row
        y = -i*l
        i += 1
        tikz_scope("yshift"=>y) do
            x = 0u"mm"
            map(direction == 1 ? row : reverse(row)) do key
                ox = x
                x += direction*(clearance + (key.width*U))
                tikz_scope("xshift"=>ox) do
                    key_node = convert(TikZnode, key, kbd.U)
                    push!(key_node.args, "anchor" => gravity)
                    convert(MIME"text/tikz", key_node)
                end
            end |> k -> join(k, "\n")
        end
    end |> r -> join(r, "\n") |> indent
    TikzPicture(rows; kwargs...)
end

TikzPictures.save(f::S, kbd::Keyboard; kwargs...) where {S<:TikzPictures.SaveType} =
    save(f, convert(TikzPicture, kbd; preamble=preamble, kwargs...))

export @keyboard_str
