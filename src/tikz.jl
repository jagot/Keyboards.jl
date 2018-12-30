using TikzPictures

const TikZarg = Union{String,<:Pair{String,<:Any}}

preamble = read(joinpath(dirname(@__FILE__), "preamble.tex"), String)

tikz_arg(arg::String) = arg
tikz_arg(arg::Pair{String,T}) where T = "$(arg[1])=$(arg[2])"

function tikz_args(args::TikZarg...)
    if !isempty(args)
        "[" * join(map(tikz_arg, args), ", ") * "]"
    else
        ""
    end
end

function indent(s::String)
    map(split(s, "\n")) do line
        "  "*line
    end |> l -> join(l, "\n")
end

function tikz_environment(fun::Function, environment::String, args::TikZarg...)
    "\\begin{$(environment)}$(tikz_args(args...))\n"*indent(fun())*"\n\\end{$(environment)}"
end

tikz_node(label::String, args::TikZarg...) = "\\node$(tikz_args(args...)){$(label)};"
tikz_scope(fun::Function, args::TikZarg...) = tikz_environment(fun, "scope", args...)
