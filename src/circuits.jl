function key1u(x₀, y₀; Dx = 8.5, Dy = 11, Drot = -150)
    x₀′ = x₀+Dx
    y₀′ = y₀+Dy

    offsetx = 9.68
    offsety = 2.06

    sx₀ = x₀ + offsetx
    sy₀ = y₀ + offsety

    S = Switch(footprint="Button_Switch_Keyboard:SW_Cherry_MX1A_1.00u_PCB",
               centerx = x₀, centery = y₀,
               offsetx = offsetx, offsety = offsety,
               model="Cherry-MX1A-E1NW.wrl"=>Dict(:scale => 0.4*[1,1,1],
                                                 :at => [-0.1,-0.2,0]),
               text=Dict("reference"=>Dict(:at => [-6,-1])))
    D = Diode(footprint="Diode_SMD:D_SMA",
              #footprint="Diode_THT:D_DO-41_SOD81_P10.16mm_Horizontal",
              x = x₀′, y = y₀′, rot=Drot,
              layers = "F"=>"B",
              manf_num = "S1A", Mouser = "512-S1A")

    c = Circuit()
    push!(c, D)
    push!(c, S)
    connect!(c, S, 1, D, "+")
    unique_labels!(c)
    key = SubCircuit(c, S=>2, D=>"-")
    # Keys in the same column connect to pin 1 of the subcircuit; keys
    # in the same row connect to pin 2.

    segment = PCBs.Segment("B.Cu", "Net", sx₀, sy₀, 0, 7.268, 0.25)

    key,segment
end

function Base.convert(::Type{Circuit}, kbd::Keyboard)
    x₀ = 0
    y₀ = 0

    l = 15
    dx = l
    dy = l

    nrows = 5
    ncols = 7

    zl = 14.224
    zx₀ = x₀
    zy₀ = y₀

    key_circuit,key_segment = key1u(x₀, y₀)
    keyboard = Circuit()

    columns = Dict{Int,Int}()
    rows = Dict{Int,Int}()

    map(enumerate(find_columns(kbd))) do (j,(col,col_keys))
        column = []
        for key in col_keys
            x,y,row = key[:centerx],key[:centery],key[:row]
            conn = []
            j ∈ keys(columns) && push!(conn, 1 => columns[j])
            row ∈ keys(rows) && push!(conn, 2 => rows[row])
            a,b = attach!(keyboard, translate(key_circuit, dx=x/u"mm", dy=-y/u"mm"), conn...)
            columns[j] = a
            rows[row] = b
        end
    end

    keyboard
end

Base.convert(::Type{PCB}, kbd::Keyboard, name::String) =
    PCB(convert(Circuit, kbd), name)
