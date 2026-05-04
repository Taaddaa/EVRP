
function insert_charging_stops(
    route    ::Vector{Int},
    stations ::Vector{Int},
    dist     ::Matrix{Float64},
    params   ::Params
)
# route=route2;stations=test_stations
# route=merged;stations=test_stations
    # Edge case: empty or trivial route
    if length(route) <= 2
        travel = route_travel_time(route, dist, params)
        return route, travel, travel <= params.max_time
    end

    new_route        = [route[1]]   # start at depot
    cum_range        = 0.0          # km since last charge (or depot)
    cum_time         = 0.0          # total minutes elapsed
    feasible         = true

    for k in 1:length(route)-1
        i = route[k]
        j = route[k+1]
        leg = dist[i, j]

        # ── Case 1: single leg exceeds max range → impossible ──
        if leg > params.max_range
            return new_route, cum_time, false
        end

        # ── Case 2: need a charge before reaching j ──
        if cum_range + leg > params.max_range

            best_station  = -1
            best_detour   = Inf

            for s in stations
                d_is = dist[i, s]
                d_sj = dist[s, j]

                # Can we reach station from i?
                d_is + cum_range > params.max_range  && continue

                # Can we reach j from station?
                d_sj > params.max_range             && continue

                # Time if we insert this station
                time_to_s   = d_is / params.speed * 60.0
                time_charge = params.charge_time
                time_s_to_j = d_sj / params.speed * 60.0
                time_after  = cum_time + time_to_s + time_charge + time_s_to_j

                # Rough remaining time check
                # (remaining route after j, ignoring future charges)
                # Rough remaining time check
                # (remaining route after j, ignoring future charges)
                remaining_dist = 0.0
                for m in k+1:length(route)-1
                     remaining_dist += dist[route[m], route[m+1]]
                end
                remaining_time = remaining_dist / params.speed * 60.0
                time_after + remaining_time > params.max_time && continue
                # Detour cost = extra distance added
                detour = d_is + d_sj - leg
                if detour < best_detour
                    best_detour  = detour
                    best_station = s
                end
            end

            # No valid station found → infeasible
            if best_station == -1
                return new_route, cum_time, false
            end

            # Insert the charging stop
            push!(new_route, best_station)
            push!(new_route, j)

            cum_time  += dist[i, best_station] / params.speed * 60.0
            cum_time  += params.charge_time
            cum_time  += dist[best_station, j] / params.speed * 60.0
            cum_range  = dist[best_station, j]   # range resets at station

        # ── Case 3: no charge needed ──
        else
            push!(new_route, j)
            cum_time  += leg / params.speed * 60.0
            cum_range += leg
        end

        # Check time budget after every step
        if cum_time > params.max_time
            return new_route, cum_time, false
        end
    end

    return new_route, cum_time, feasible
end

function insert_charging_stops_WO_CH(
    route    ::Vector{Int},
    dist     ::Matrix{Float64},
    params   ::Params
    )

    if length(route) <= 2
        travel = route_travel_time(route, dist, params)
        return route, travel, travel <= params.max_time
    end

    new_route = [route[1]]
    cum_range = 0.0
    cum_time  = 0.0
    feasible  = true
    n         = params.n_customers + 1

    for k in 1:length(route)-1
        i   = route[k]
        j   = route[k+1]
        leg = dist[i, j]

        # ── Case 1: single leg physically impossible ──
        if leg > params.max_range
            push!(new_route, j)
            cum_time += leg / params.speed * 60.0
            cum_range = leg
            # still continue — we track time feasibility separately
            if cum_time > params.max_time
                return new_route, cum_time, false
            end
            continue
        end

        # ── Case 2: range would be violated → score candidates ──
        if cum_range + leg > params.max_range
            cum_range = leg   # reset range as if we charged here
            cum_time  += params.charge_time    # 30 min charge cost
            cum_time  += leg / params.speed * 60.0
            # ── Check time budget ──
            if cum_time > params.max_time
                return new_route, cum_time, false
            end
        # ── Case 3: no violation → normal travel ──
        else
            cum_range += leg
            cum_time  += leg / params.speed * 60.0

            if cum_time > params.max_time
                return new_route, cum_time, false
            end
        end

        push!(new_route, j)
    end

    return new_route, cum_time, feasible
end

function charger_local_search(
    t0          ::Float64,
    snaps:: Vector{Snapshot},
    alns_sol   ::Solution,
    initial_stations::Vector{Int},
    dist            ::Matrix{Float64},
    params          ::Params;
    max_iter        ::Int  = 50,
    verbose         ::Bool = true
)
    # All possible charger locations (customer indices)
    all_customers = collect(2:params.n_customers+1)

    # Evaluate initial placement
    best_stations = copy(initial_stations)
    # best_sol      = evaluate_stations(best_stations, dist, params)
    best_sol      = alns_sol
    if verbose
        println("\n" * "=" ^ 55)
        println("Charger Local Search")
        println("=" ^ 55)
        @printf("  Initial stations: %s\n", string(best_stations .- 1))
        @printf("  Initial result:   %d vehicles | %.2f km\n",
                best_sol.n_vehicles, best_sol.total_dist)
        println("-" ^ 55)
    end

    improved = true
    iter     = 0

    while improved && iter < max_iter
        improved = false
        iter    += 1

        # Try swapping each station with each non-station customer
        for (sidx, station) in enumerate(best_stations)
            # sidx,station= collect(enumerate(best_stations))[1]
            for candidate in all_customers
                # candidate=all_customers[1]
                candidate in best_stations && continue

                # Build new station set with swap
                new_stations    = copy(best_stations)
                new_stations[sidx] = candidate

                # Evaluate
                new_sol = evaluate_stations(new_stations, dist, params)

                # Keep if better (fewer vehicles, or same vehicles less distance)
                if new_sol.cost < best_sol.cost
                    best_stations = new_stations
                    best_sol      = new_sol
                    improved      = true
                    push!(snaps, Snapshot(elapsed(t0), "Charger local Search:" *@sprintf("  Iter %2d: swap C%d→C%d",
                                iter,
                                station-1, candidate-1) ,best_sol))

                    if verbose
                        @printf("  Iter %2d: swap C%d→C%d | %d veh | %.2f km ✓\n",
                                iter,
                                station-1, candidate-1,
                                best_sol.n_vehicles, best_sol.total_dist)
                    end
                end
            end
        end

        !improved && verbose && println("  No improvement found — stopping.")
    end

    if verbose
        println("-" ^ 55)
        @printf("  BEST STATIONS:  %s\n", string(best_stations .- 1))
        @printf("  BEST RESULT:    %d vehicles | %.2f km\n",
                best_sol.n_vehicles, best_sol.total_dist)
        println("=" ^ 55)
    end

    return snaps,best_stations, best_sol
end

function evaluate_stations(
    stations::Vector{Int},
    dist    ::Matrix{Float64},
    params  ::Params;
    verbose ::Bool = false
)
    cw  = clarke_wright(dist, stations, params)
    sol, _, _ = alns(cw, stations, dist, params, verbose=verbose;reduced=true)
    return sol
end

