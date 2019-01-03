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

function coordinates(kbd::Keyboard, x₀::Length=0u"mm", y₀::Length=0u"mm")
    direction = kbd.gravity == :nw ? 1 : -1
    @unpack U,clearance = kbd
    l = U + clearance
    i = 0
    map(enumerate(kbd.rows)) do (i,row)
        y = y₀ - (i-1)*l
        x = x₀
        map(enumerate(row)) do (j,key)
            ox = x
            x += direction*(clearance + key.width*U)
            Dict(:x => ox, :y => y,
                 :centerx => ox + direction*key.width*U/2,
                 :centery => y - direction*key.height*U/2,
                 :key => key)
        end
    end
end

function Base.unique!(v::Vector{T}, s::T, e::T) where T
    length(v) > length(s:e) &&
        throw(ArgumentError("Impossible to shift elements of vector with only $(length(s:e)) choices available"))

    while !allunique(v)
        function shift!(i::Int, d::Int)
            di,sel = if d < 0
                d = -d
                -1,d:i
            else
                1,i:d
            end
            for j in sel
                v[j] += di
            end
        end

        i = findfirst(i -> v[i]==v[i-1], 2:length(v))
        fwd = findfirst(j -> v[j] < (j < length(v) ? v[j+1]-1 : e), i+1:length(v))
        bwd = findfirst(j -> v[j] > (j > 1 ? v[j-1]+1 : s), 1:i-1)

        if fwd != nothing || bwd != nothing
            if fwd != nothing && bwd != nothing && fwd < abs(i-bwd) || fwd != nothing
                shift!(i+1, fwd+i)
            else
                shift!(i, -(bwd+1))
            end
        else
            throw(ArgumentError("Cannot continue, no shift will improve uniqueness"))
        end
    end

    v
end

function find_columns(kbd::Keyboard)
    coords = map(coordinates(kbd)) do row
        filter(k -> k[:key] isa Keyboards.Key, row)
    end
    num_columns = 0
    maxi = 0
    centers = map(enumerate(coords)) do (i,row)
        num_columns = max(num_columns, length(row))
        length(row) == num_columns && (maxi = i)
        map(row) do key
            key[:centerx],key[:centery]
        end
    end
    @info "$(num_columns) columns required"
    @info "Row # with max columns: $(maxi)"
    column_centers = first.(centers[maxi])

    key_mappings = map(coords) do row
        mapping = map(row) do key
            argmin(abs.(key[:centerx] .- column_centers))
        end
        unique!(mapping, 1, num_columns)
        map(enumerate(mapping)) do (i,c)
            c => row[i]
        end
    end

    columns = [x => Dict[] for x in column_centers]
    for row in key_mappings
        for k in row
            push!(columns[k[1]][2], k[2])
        end
    end

    columns
end

# * TikZ conversion

function Base.convert(::Type{TikzPicture}, kbd::Keyboard; draw_centers::Bool=false, kwargs...)
    @unpack U,clearance = kbd
    gravity,direction = if kbd.gravity == :nw
        "north west",1
    else
        "north east",-1
    end
    coords = coordinates(kbd)
    rows = map(enumerate(kbd.rows)) do (i,row)
        y = first(coords[i])[:y]
        tikz_scope("yshift"=>y) do
            map(enumerate(row)) do (j,key)
                x = coords[i][j][:x]
                tikz_scope("xshift"=>x) do
                    key_node = convert(TikZnode, key, kbd.U)
                    push!(key_node.args, "anchor" => gravity)
                    kns = convert(MIME"text/tikz", key_node)
                    kns * if draw_centers
                        id = key isa Key ? "k"*string(hash(key)) : ""
                        center_node = TikZnode("", "red", "draw", "circle",
                                               id = id,
                                               x = coords[i][j][:centerx]-x,
                                               y = coords[i][j][:centery]-y)
                        convert(MIME"text/tikz", center_node)
                    else
                        ""
                    end
                end
            end |> k -> join(k, "\n")
        end
    end |> r -> join(r, "\n") |> indent
    columns = if draw_centers
        map(find_columns(kbd)) do (column,keys)
            c = map(keys) do key
                "(k$(hash(key[:key])))"
            end |> k -> join(k, " -- ")
            "\\draw[red] $(c);"
        end |> c -> join(c, "\n") |> indent
    else
        ""
    end
    TikzPicture(rows*"\n"*columns; kwargs...)
end

TikzPictures.save(f::S, kbd::Keyboard; kwargs...) where {S<:TikzPictures.SaveType} =
    save(f, convert(TikzPicture, kbd; preamble=preamble, kwargs...))

export @keyboard_str
