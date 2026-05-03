function nearest_neighbor_routes(dist::Matrix{Float64}, params::Params)
    depot     = 1
    n         = params.n_customers + 1
    unvisited = Set(2:n)
    routes    = Vector{Vector{Int}}()

    while !isempty(unvisited)
        route   = [depot]
        current = depot
        cum_dist = 0.0

        while true
            # Find nearest unvisited within time budget
            best_d    = Inf
            best_node = -1

            for node in unvisited
                d = dist[current, node]
                # rough check: can we get there and back?
                back = dist[node, depot]
                if cum_dist + d + back <= params.max_time/60 * params.speed
                    if d < best_d
                        best_d    = d
                        best_node = node
                    end
                end
            end

            best_node == -1 && break

            push!(route, best_node)
            cum_dist += best_d
            current   = best_node
            delete!(unvisited, best_node)
        end

        push!(route, depot)
        length(route) > 2 && push!(routes, route)
    end

    return routes
end