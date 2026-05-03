
####################
#Removel operators
####################

function random_removal(
    routes::Vector{Vector{Int}},
    k     ::Int,
    n     ::Int
)
    removed  = Int[]

    # Collect all removable customers (not depot)
    all_customers = 2:n+1
    # all_customers = Int[]
    # for route in routes
    #     append!(all_customers, route[2:end-1])
    # end
    # Sample k customers
    k = min(k, n)
    to_remove = Set(shuffle(all_customers)[1:k])

    # Remove from routes
    removed = Int[]
    #remove "to_remove" from routes
    new_routes = deepcopy(routes)
    for (i,route) in enumerate(routes)
        # route=routes[2]
        rem=findall(n -> n in to_remove, route)
        if !isempty(rem)
            removed=vcat(removed, route[rem])
            new_routes[i] = route[Not(rem)]
        end
    end
    #
    # routes_2=deepcopy(routes)
    # for (idx, route) in enumerate(routes)
    #     new_route = [route[1]]
    #     for node in route[2:end-1]
    #         if node in to_remove
    #             push!(removed, node)
    #         else
    #             push!(new_route, node)
    #         end
    #     end
    #     push!(new_route, route[end])
    #     routes_2[idx] = new_route
    # end
    # routes_2=deepcopy(routes)
    # Remove empty routes (only depot→depot)
    new_routes = filter(r -> length(r) > 2, new_routes)
    return new_routes, removed
end

# ── B2: Worst Removal ──
# Remove k customers that contribute most to total distance
function worst_removal(
    routes::Vector{Vector{Int}},
    k     ::Int,
    dist  ::Matrix{Float64}
)
    # Score each customer by removal savings
    # saving = d(prev,node) + d(node,next) - d(prev,next)
    scores=Vector{Float64}(undef, size(dist,1)-1)
    for route in routes
        for pos in 2:length(route)-1
            prev = route[pos-1]
            node = route[pos]
            next = route[pos+1]
            scores[node-1] = dist[prev,node] + dist[node,next] - dist[prev,next]
        end
    end

    # Sort by score descending → worst customers first
    sorted = sortperm(scores, rev=true).+1
    k      = min(k, length(sorted))
    to_remove = Set(sorted[1:k])

    removed = Int[]
    #remove "to_remove" from routes
    new_routes = deepcopy(routes)
    for (i,route) in enumerate(routes)
        # route=routes[2]
        rem=findall(n -> n in to_remove, route)
        if !isempty(rem)
            removed=vcat(removed, route[rem])
            new_routes[i] = route[Not(rem)]
        end
    end
    new_routes = filter(r -> length(r) > 2, new_routes)
    return new_routes, removed
end

# ── B3: Related Removal ──
# Remove k customers that are geographically close to each other
# Motiviation: close customers are likely better reorganized together
function related_removal(
    routes::Vector{Vector{Int}},
    k     ::Int,
    dist  ::Matrix{Float64},
    n    ::Int
)
    # Collect all customers
    all_customers = 2:n+1


    # Start from a random customer
    seed     = rand(all_customers)
    to_remove = [seed]

    # Iteratively add the closest customer to already-selected set
    remaining = filter(c -> c != seed, all_customers)
    while length(to_remove) < min(k, length(all_customers))
        # Find customer in remaining closest to any in to_remove
        best_c = -1
        best_d = Inf
        for c in remaining
            min_d = minimum(dist[c, r] for r in to_remove)
            if min_d < best_d
                best_d = min_d
                best_c = c
            end
        end
        best_c == -1 && break
        push!(to_remove, best_c)
        filter!(c -> c != best_c, remaining)
    end

    to_remove = Set(to_remove)
    removed = Int[]
    #remove "to_remove" from routes
    new_routes = deepcopy(routes)
    for (i,route) in enumerate(routes)
        # route=routes[2]
        rem=findall(n -> n in to_remove, route)
        if !isempty(rem)
            removed=vcat(removed, route[rem])
            new_routes[i] = route[Not(rem)]
        end
    end
    new_routes = filter(r -> length(r) > 2, new_routes)
    return new_routes, removed
end


####################
#Repair operators
####################
# ── C1: Greedy Insertion ──
# Insert each removed customer at the cheapest feasible position
function greedy_insertion(
    routes  ::Vector{Vector{Int}},
    removed ::Vector{Int},
    stations::Vector{Int},
    dist    ::Matrix{Float64},
    params  ::Params;
    WO_CH    ::Bool = false
)
    # new_routes  = deepcopy(destroyed)
    new_routes  = deepcopy(routes)
    # Shuffle to avoid bias
    removed = shuffle(removed)

    for customer in removed
        best_cost = Inf
        best_route_idx = -1
        best_pos       = -1

        for (ridx, route) in enumerate(routes)
            for pos in 2:length(route)
                # Insert customer at position pos
                new_route = vcat(route[1:pos-1], [customer], route[pos:end])

                # Check feasibility
                if WO_CH
                    _, t, feasible = insert_charging_stops_WO_CH(
                        new_route, dist, params)
                else
                _, t, feasible = insert_charging_stops(
                    new_route, stations, dist, params)
                end
                !feasible && continue

                # Cost = insertion distance cost
                prev = route[pos-1]
                next = route[pos]
                cost = dist[prev,customer] + dist[customer,next] - dist[prev,next]

                if cost < best_cost
                    best_cost      = cost
                    best_route_idx = ridx
                    best_pos       = pos
                end
            end
        end

        if best_route_idx != -1
            # Insert into best position
            r = new_routes[best_route_idx]
            new_routes[best_route_idx] = vcat(r[1:best_pos-1], [customer], r[best_pos:end])
        else
            # No feasible position found → open new route
            push!(new_routes, [1, customer, 1])
        end
    end

    return new_routes
end

# ── C2: Regret-2 Insertion ──
# Insert customer with highest regret first
# Regret = difference between best and 2nd best insertion cost
# Motivation: prioritize customers that MUST go in their best spot
function regret2_insertion(
    routes  ::Vector{Vector{Int}},
    removed ::Vector{Int},
    stations::Vector{Int},
    dist    ::Matrix{Float64},
    params  ::Params;
    WO_CH    ::Bool = false
)
    new_routes  = deepcopy(routes)
    pending = deepcopy(removed)

    # if WO_CH
    #     insert_charging=insert_charging_stops_WO_CH
    # else
    #     insert_charging=insert_charging_stops
    # end
    while !isempty(pending)
        best_regret    = -Inf
        best_customer  = -1
        best_route_idx = -1
        best_pos       = -1

        for customer in pending
            costs = Float64[]

            for (ridx, route) in enumerate(routes)
                for pos in 2:length(route)
                    new_route = vcat(route[1:pos-1], [customer], route[pos:end])
                    if WO_CH
                        _, t, feasible = insert_charging_stops_WO_CH(
                            new_route, dist, params)
                    else
                    _, t, feasible = insert_charging_stops(
                        new_route, stations, dist, params)
                    end
                    !feasible && continue

                    prev = route[pos-1]
                    next = route[pos]
                    c    = dist[prev,customer] + dist[customer,next] - dist[prev,next]
                    push!(costs, c)
                end
            end

            if length(costs) >= 2
                sort!(costs)
                regret = costs[2] - costs[1]
            elseif length(costs) == 1
                regret = costs[1]*1000    # only one option → high priority
            else
                regret = Inf         # must open new route
            end

            if regret > best_regret
                best_regret   = regret
                best_customer = customer
            end
        end
        # Find best position for this customer
        best_c = Inf
        for (ridx, route) in enumerate(routes)
            for pos in 2:length(route)
                new_route = vcat(route[1:pos-1], [best_customer], route[pos:end])
                if WO_CH
                    _, t, feasible = insert_charging_stops_WO_CH(
                        new_route, dist, params)
                else
                _, t, feasible = insert_charging_stops(
                    new_route, stations, dist, params)
                end
                !feasible && continue
                prev = route[pos-1]
                next = route[pos]
                c    = dist[prev,best_customer] + dist[best_customer,next] - dist[prev,next]
                if c < best_c
                    best_c         = c
                    best_route_idx = ridx
                    best_pos       = pos
                end
            end
        end


        # Insert the highest-regret customer
        if best_route_idx != -1 && best_customer != -1
            r = routes[best_route_idx]
            routes[best_route_idx] = vcat(
                r[1:best_pos-1], [best_customer], r[best_pos:end])
        else
            # No feasible position → new route
            if best_customer != -1
                push!(routes, [1, best_customer, 1])
            end
        end

        filter!(c -> c != best_customer, pending)
    end

    return routes
end

function accept_sa(
    new_cost    ::Float64,
    current_cost::Float64,
    T           ::Float64
)
    new_cost < current_cost && return true
    Δ = new_cost - current_cost
    return rand() < exp(-Δ / T)
end


function update_scores!(
    wm      ::WeightManager,
    d_idx   ::Int,
    r_idx   ::Int,
    reward  ::Float64
)
    wm.destroy_scores[d_idx] += reward
    wm.repair_scores[r_idx]  += reward
    wm.destroy_counts[d_idx] += 1
    wm.repair_counts[r_idx]  += 1
end

function update_weights!(wm::WeightManager)
    # Update destroy weights
    for i in 1:length(wm.destroy_weights)
        if wm.destroy_counts[i] > 0
            wm.destroy_weights[i] = wm.destroy_weights[i] * wm.decay +
                (wm.destroy_scores[i] / wm.destroy_counts[i]) * (1 - wm.decay)
        end
        # Ensure minimum weight so operator is never ignored
        wm.destroy_weights[i] = max(wm.destroy_weights[i], 0.01)
    end

    # Update repair weights
    for i in 1:length(wm.repair_weights)
        if wm.repair_counts[i] > 0
            wm.repair_weights[i] = wm.repair_weights[i] * wm.decay +
                (wm.repair_scores[i] / wm.repair_counts[i]) * (1 - wm.decay)
        end
        wm.repair_weights[i] = max(wm.repair_weights[i], 0.01)
    end

    # Reset segment scores and counts
    fill!(wm.destroy_scores, 0.0)
    fill!(wm.repair_scores,  0.0)
    fill!(wm.destroy_counts, 0)
    fill!(wm.repair_counts,  0)
end
