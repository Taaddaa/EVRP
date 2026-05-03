function compute_savings(dist::Matrix{Float64})
    n=size(dist, 1)
    depot    = 1
    savings  = Saving[]

    for i in 2:n
        for j in 2:n
            i == j && continue
            s = dist[depot,i] + dist[depot,j] - dist[i,j]
            push!(savings, Saving(i, j, s))
        end
    end

    # Sort descending by saving value
    sort!(savings, by = s -> s.value, rev = true)
    return savings
end

#    - which route each customer belongs to
#    - what's at the start/end of each route
#    - merge two routes together
function init_route_tracker(params::Params)
    n       = params.n_customers
    routes  = [[1, i+1, 1] for i in 1:n]   # depot→customer→depot for each
    route_of    = collect(2:n+1)            # customer i+1 is in route i
    # Build route_of correctly
    route_of_map = zeros(Int, n+1)
    for (idx, route) in enumerate(routes)
        for node in route[2:end-1]
            route_of_map[node] = idx
        end
    end
    is_interior = falses(n+1)

    return RouteTracker(routes, route_of_map, is_interior)
end


function clarke_wright(
    dist    ::Matrix{Float64},
    stations::Vector{Int},
    params  ::Params
)
# stations=test_stations
    depot   = 1
    n       = params.n_customers+1

    # Step 1: initialize — every customer its own route
    # route_id[i] = which route customer i belongs to
    # route_id = collect(1:n)     # customer i → route i (1-indexed)
    routes   = Vector{Vector{Int}}()
    for i in 2:n
        push!(routes, [depot, i, depot])
    end
    route_id = zeros(Int, n)
    for (idx, route) in enumerate(routes)
        route_id[route[2]] = idx
    end

    # Track which end customers are at
    # A merge is only valid if:
    #   i is the LAST customer in its route (before depot)
    #   j is the FIRST customer in its route (after depot)
    # Step 2: compute and sort savings
    savings = compute_savings(dist)

    # Step 3: greedy merge
    for s in savings
        # s=savings[1]
        i = s.i
        j = s.j
        s.value <= 0 && break    # no more positive savings

        ri = route_id[i]
        rj = route_id[j]

        # Must be in different routes
        ri == rj && continue
        # ri == 0  && continue
        # rj == 0  && continue

        route_i = routes[ri]
        route_j = routes[rj]

        # i must be last customer in its route
        route_i[end-1]  != i && continue

        # j must be first customer in its route
        route_j[2] != j && continue

        # Build merged route: drop trailing depot of route_i
        # and leading depot of route_j
        merged = vcat(route_i[1:end-1], route_j[2:end])

        # Check feasibility with charging
        _, t, feasible = insert_charging_stops(merged, stations, dist, params) #Tahmine: This function can be improved so we can charge with pre-caution, sonner that it really needed
        !feasible && continue

        # Merge is valid — update data structures
        routes[ri] = merged
        routes[rj] = Int[]       # mark route rj as deleted

        # Update route_id for all customers in old route_j
        for node in route_j[2:end-1]
            route_id[node] = ri
        end
    end

    # Step 4: collect non-empty routes
    final_routes = filter(r -> length(r) > 0, routes)
    return final_routes
end
# ------------------------------------------------------------
#  Clarke-Wright WITHOUT charging constraints
#  Merges routes based only on time feasibility
#  Accumulates violation scores during feasibility checks
# ------------------------------------------------------------

function clarke_wright_WO_CH(
    dist    ::Matrix{Float64},
    params  ::Params
)
    depot    = 1
    n        = params.n_customers+1

    # ── Step 1: every customer gets its own route ──
    routes   = Vector{Vector{Int}}()
    for i in 2:n
        push!(routes, [depot, i, depot])
    end

    route_id = zeros(Int, n)
    for (idx, route) in enumerate(routes)
        route_id[route[2]] = idx
    end
    # ── Step 2: compute savings ──
    savings = compute_savings(dist)

    # ── Step 3: greedy merge (time only, no range check) ──
    for s in savings
        # s=savings[1]
        i = s.i
        j = s.j
        s.value <= 0 && break

        ri = route_id[i]
        rj = route_id[j]

        ri == rj && continue
        ri == 0  && continue
        rj == 0  && continue

        route_i = routes[ri]
        route_j = routes[rj]

        isempty(route_i) && continue
        isempty(route_j) && continue

        route_i[end-1]  != i && continue
        route_j[2] != j && continue

        merged = vcat(route_i[1:end-1], route_j[2:end])

        # Feasibility check: time only, range violations scored
        _, t, feasible = insert_charging_stops_WO_CH(merged, dist, params)
        !feasible && continue
        # ── Accept merge ──
        routes[ri] = merged
        routes[rj] = Int[]

        for node in route_j[2:end-1]
            route_id[node] = ri
        end
    end

    # ── Step 4: collect routes ──
    final_routes = filter(r -> length(r) > 0, routes)

    return final_routes
end

