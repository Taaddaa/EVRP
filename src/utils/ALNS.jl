
function alns(
    initial_routes::Vector{Vector{Int}},
    stations      ::Vector{Int},
    dist          ::Matrix{Float64},
    params        ::Params;
    verbose       ::Bool = true,
    reduced       ::Bool = false
)
    if reduced
        alns_iter = params.reduced_iter
        segment_size = params.reduced_segment_size
    else
        alns_iter = params.max_iter
        segment_size = params.segment_size
    end
    # ── Initialize ──
    current = make_solution(initial_routes, stations, dist, params)
    best    = deepcopy(current)
    wm= WeightManager(["Random", "Worst", "Related"], ["Greedy", "Regret2"], # 3 destroy and 2 repair operators
        ones(3), ones(2), zeros(3), zeros(2), zeros(Int, 3), zeros(Int, 2),
        params.decay, params.sigma1, params.sigma2, params.sigma3)  
    T       = params.T_start

    # Scale temperatures by initial cost
    T_start  = params.T_start * current.cost
    T_end    = params.T_end   * current.cost
    T        = T_start
    cooling  = (T_end / T_start) ^ (1.0 / alns_iter)

    # Track history for analysis
    history_best    = Float64[]
    history_current = Float64[]
    history_vehicles= Int[]

    if verbose
        println("\n" * "=" ^ 55)
        println(" ALNS - Improving Routes")
        println("=" ^ 55)
        @printf("  Initial: %d vehicles | cost: %.2f\n",
                current.n_vehicles, current.cost)
        @printf("  T_start: %.4f | T_end: %.6f | cooling: %.6f\n",
                T_start, T_end, cooling)
        println("-" ^ 55)
    end

    for iter in 1:alns_iter

        # ── Select operators ──
        d_idx = select_operator(wm.destroy_weights)
        r_idx = select_operator(wm.repair_weights)

        # ── Removal size ──
        k = rand(params.removal_min:params.removal_max)

        # ── Destroy ──
        # routes=current.routes;n=params.n_customers
        destroyed, removed = if d_idx == 1
            random_removal(current.routes, k , params.n_customers)
        elseif d_idx == 2
            worst_removal(current.routes, k, dist)
        else
            related_removal(current.routes, k, dist, params.n_customers)
        end

        # isempty(removed) && continue

        # ── Repair ──
        repaired = if r_idx == 1
            greedy_insertion(destroyed, removed, stations, dist, params)
        else
            regret2_insertion(destroyed, removed, stations, dist, params)
        end

        # ── Evaluate ──
        new_sol = make_solution(repaired, stations, dist, params)

        # ── Reward ──
        reward = 0.0
        if new_sol.cost < best.cost
            reward = wm.sigma1          # new global best
            best   = deepcopy(new_sol)
        elseif new_sol.cost < current.cost
            reward = wm.sigma2          # better than current
        elseif accept_sa(new_sol.cost, current.cost, T)
            reward = wm.sigma3          # accepted but not better
        end

        # ── Accept ──
        if new_sol.cost < current.cost || accept_sa(new_sol.cost, current.cost, T)
            current = new_sol
        end

        # ── Update scores ──
        update_scores!(wm, d_idx, r_idx, reward)

        # ── Update weights every segment ──
        if iter % segment_size == 0
            update_weights!(wm)
        end

        # ── Cool temperature ──
        T *= cooling

        # ── Track history ──
        push!(history_best,     best.n_vehicles)
        push!(history_current,  current.n_vehicles)
        push!(history_vehicles, best.n_vehicles)

        # ── Progress report ──
        if verbose && iter % 1000 == 0
            @printf("  Iter %5d | best: %d veh | current: %d veh | T: %.6f\n",
                    iter, best.n_vehicles, current.n_vehicles, T)
            @printf("  Weights D: [%.2f %.2f %.2f] R: [%.2f %.2f]\n",
                    wm.destroy_weights..., wm.repair_weights...)
        end
    end

    if verbose
        println("-" ^ 55)
        @printf("  FINAL: %d vehicles | dist: %.2f km\n",
                best.n_vehicles, best.total_dist)
        println("=" ^ 55)
    end

    return best, history_best, history_current
end


function alns_WO_CH(
    initial_routes::Vector{Vector{Int}},
    dist          ::Matrix{Float64},
    params        ::Params;
    verbose       ::Bool = true,
    reduced       ::Bool = false
)
    if reduced
        alns_iter = params.reduced_iter
        segment_size = params.reduced_segment_size
    else
        alns_iter = params.max_iter
        segment_size = params.segment_size
    end
    stations=collect(2:params.n_customers+1) # Dummy stations for WO_CH ALNS
    
    # ── Initialize ──
    current = make_solution(initial_routes, stations, dist, params)
    best    = deepcopy(current)
    wm= WeightManager(["Random", "Worst", "Related"], ["Greedy", "Regret2"], # 3 destroy and 2 repair operators
        ones(3), ones(2), zeros(3), zeros(2), zeros(Int, 3), zeros(Int, 2),
        params.decay, params.sigma1, params.sigma2, params.sigma3)  
    T       = params.T_start

    # Scale temperatures by initial cost
    T_start  = params.T_start * current.cost
    T_end    = params.T_end   * current.cost
    T        = T_start
    cooling  = (T_end / T_start) ^ (1.0 / alns_iter)

    # Track history for analysis
    history_best    = Float64[]
    history_current = Float64[]
    history_vehicles= Int[]

    if verbose
        println("\n" * "=" ^ 55)
        println(" ALNS for Initial Solution (Without Charger Insertion)")
        println("=" ^ 55)
        @printf("  Initial: %d vehicles | cost: %.2f\n",
                current.n_vehicles, current.cost)
        @printf("  T_start: %.4f | T_end: %.6f | cooling: %.6f\n",
                T_start, T_end, cooling)
        println("-" ^ 55)
    end

    for iter in 1:alns_iter

        # ── Select operators ──
        d_idx = select_operator(wm.destroy_weights)
        r_idx = select_operator(wm.repair_weights)

        # ── Removal size ──
        k = rand(params.removal_min:params.removal_max)

        # ── Destroy ──
        # routes=current.routes;n=params.n_customers
        destroyed, removed = if d_idx == 1
            random_removal(current.routes, k , params.n_customers)
        elseif d_idx == 2
            worst_removal(current.routes, k, dist)
        else
            related_removal(current.routes, k, dist, params.n_customers)
        end

        # isempty(removed) && continue

        # ── Repair ──
        repaired = if r_idx == 1
            greedy_insertion(destroyed, removed, stations, dist, params; WO_CH = true)
        else
            regret2_insertion(destroyed, removed, stations, dist, params; WO_CH = true)
        end

        # ── Evaluate ──
        new_sol = make_solution(repaired, stations, dist, params)

        # ── Reward ──
        reward = 0.0
        if new_sol.cost < best.cost
            reward = wm.sigma1          # new global best
            best   = deepcopy(new_sol)
        elseif new_sol.cost < current.cost
            reward = wm.sigma2          # better than current
        elseif accept_sa(new_sol.cost, current.cost, T)
            reward = wm.sigma3          # accepted but not better
        end

        # ── Accept ──
        if new_sol.cost < current.cost || accept_sa(new_sol.cost, current.cost, T)
            current = new_sol
        end

        # ── Update scores ──
        update_scores!(wm, d_idx, r_idx, reward)

        # ── Update weights every segment ──
        if iter % segment_size == 0
            update_weights!(wm)
        end

        # ── Cool temperature ──
        T *= cooling

        # ── Track history ──
        push!(history_best,     best.n_vehicles)
        push!(history_current,  current.n_vehicles)
        push!(history_vehicles, best.n_vehicles)

        # ── Progress report ──
        if verbose && iter % 1000 == 0
            @printf("  Iter %5d | best: %d veh | current: %d veh | T: %.6f\n",
                    iter, best.n_vehicles, current.n_vehicles, T)
            @printf("  Weights D: [%.2f %.2f %.2f] R: [%.2f %.2f]\n",
                    wm.destroy_weights..., wm.repair_weights...)
        end
    end

    if verbose
        println("-" ^ 55)
        @printf("  FINAL Solution - ALNS Without Charger Insertion: %d vehicles | dist: %.2f km\n",
                best.n_vehicles, best.total_dist)
        println("=" ^ 55)
    end

    return best, history_best, history_current
end

