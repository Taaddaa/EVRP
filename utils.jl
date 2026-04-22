function parse_costumers(filename)
    # costumers = Dict{String, Tuple{Float64, Float64}}()
    costumers= DataFrame(name=String[], x=Float64[], y=Float64[])
    open(filename, "r") do file
        for (i, line) in enumerate(eachline(file))
            # println("Parsing line $i: $line")
            if !isempty(line)
                x, y =  parse.(Float64, split(line, "\t"))
                push!(costumers, (name="c_$i", x=x, y=y))
            end
        end
    end
    return costumers
end