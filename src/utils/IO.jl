
function parse_costumers(filename,depot)
    # costumers = Dict{String, Tuple{Float64, Float64}}()
    costumers= DataFrame(name=String[], x=Float64[], y=Float64[])
    locations= zeros(Float64, 0, 2)
    open(filename, "r") do file
        for (i, line) in enumerate(eachline(file))
            # println("Parsing line $i: $line")
            if !isempty(line)
                x, y =  parse.(Float64, split(line, "\t"))
                push!(costumers, (name="c_$i", x=x, y=y))
                locations = vcat(locations, [x y])
            end
        end
    end
    costumers[:, :routes] .=0
    locations = vcat([depot.x depot.y], locations)  # Add depot at the beginning
    return costumers,locations
end


function set_problem(;
    max_range    = 40.0,
    charge_time  = 30.0
    )
    max_iter     = 10000
    reduced_iter   = 500
    worse_accept = 0.05     # 5% worse solution accepted at start
    accept_prob  = 0.50     # with 50% probability at start
    n_customers  = 98
    max_time     = 240.0    # 8am to noon = 240 min
    speed        = 30.0     
    n_chargers   = 5
    segment_size = 100
    reduced_segment_size = 30
    decay        = 0.8
    sigma1       = 33.0
    sigma2       = 9.0
    sigma3       = 3.0
    removal_min  = 3
    removal_max  = 15

    # SA temperature calibration
    # T_start: 5% worse solution accepted with 50% probability
    T_start      = -worse_accept / log(accept_prob)

    # T_end: 1% worse solution accepted with 1% probability
    T_end        = -0.01 / log(0.01)

    # Cooling rate spans T_start to T_end over max_iter
    cooling_rate = (T_end / T_start) ^ (1.0 / max_iter)

    return Params(
        n_customers, max_range, max_time, speed,
        charge_time, n_chargers,
        max_iter, reduced_iter, segment_size, reduced_segment_size, decay,
        sigma1, sigma2, sigma3,
        removal_min, removal_max,
        T_start, T_end, cooling_rate
    )
end

function print_route(
    route    ::Vector{Int},
    stations ::Vector{Int},
    dist     ::Matrix{Float64},
    params   ::Params;
    route_id ::Int = 1
)
    new_route, total_time, feasible = insert_charging_stops(route, stations, dist, params)
    total_dist = route_travel_dist(new_route, dist)

    @printf("\nRoute %d: ", route_id)
    for (k, node) in enumerate(new_route)
        if node == 1
            print("DEPOT")
        elseif node in stations
            print("⚡C$(node-1)")   # charging stop
        else
            print("C$(node-1)")    # regular customer
        end
        k < length(new_route) && print(" → ")
    end

    @printf("\n  Customers: %d | Charges: %d | Dist: %.2f km | Time: %.1f min | %s\n",
        length(route) - 2,
        count(n -> n in stations, new_route) - count(n -> n in stations, route),
        total_dist,
        total_time,
        feasible ? "✓ OK" : "✗ INFEASIBLE"
    )
end

function print_solution(
    routes  ::Vector{Vector{Int}},
    stations::Vector{Int},
    dist    ::Matrix{Float64},
    params  ::Params;
    label   ::String = "SOLUTION"
)
    println("\n" * "=" ^ 55)
    println("  $label")
    println("=" ^ 55)

    total_dist    = 0.0
    total_time    = 0.0
    total_charges = 0

    for (idx, route) in enumerate(routes)
        new_route, t, feasible = insert_charging_stops(route, stations, dist, params)
        d = route_travel_dist(new_route, dist)
        n_charges = count(n -> n in stations, new_route) -
                    count(n -> n in stations, route)
        n_charges = count(n -> n in stations, new_route)

        total_dist    += d
        total_time    += t
        total_charges += n_charges

        @printf("  Route %2d: %2d customers | %d charges | %6.2f km | %5.1f min | %s\n",
            idx,
            length(route) - 2,
            n_charges,
            d, t,
            feasible ? "✓" : "✗ INFEASIBLE"
        )
    end

    println("-" ^ 55)
    @printf("  Vehicles:       %d\n",      length(routes))
    @printf("  Total distance: %.2f km\n", total_dist)
    @printf("  Total time:     %.1f min\n",total_time)
    @printf("  Charge stops:   %d\n",      total_charges)
    @printf("  Stations used:  %s\n",      string(stations .- 1))  # show as customer numbers
    println("=" ^ 55)
end
function initial_charger_print(initial_stations::Vector{Int}, params::Params)
    # Sort customers by score descending
    # Only consider customer indices (2..99)
    candidates = collect(2:params.n_customers+1)
    println("\n" * "=" ^ 55)
    println("  SECTION 6A — Initial Charger Placement")
    println("=" ^ 55)
    println("  Violation scores (top 10 candidates):")
    for c in candidates[1:10]
        @printf("    Customer %2d (idx %2d): score = %.1f\n",
                c-1, c, scores[c])
    end
    @printf("\n  Selected stations (customer indices): %s\n",
            string(initial_stations .- 1))
    println("=" ^ 55)

    # return initial_stations
end