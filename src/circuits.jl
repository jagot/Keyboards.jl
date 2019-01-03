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

    segment = PCBs.Segment("B.Cu", "Net", sx₀, sy₀, 0, 7.268, 0.25)

    key,segment
end
