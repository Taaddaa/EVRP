include("utils/packages.jl")

##########################################
#Block 1: Load data, build distance matrix
##########################################

depot= (x=18.190, y=6.320)
Costumer_Data, locations = parse_costumers(pwd()*"/Data/costumers.txt", depot)
dist= build_dist_matrix(locations)
# scenario_name="40km_range, 30m_chargetime"
# params=set_problem(;max_range    = 40.0, charge_time  = 30.0)
scenario_names=["40km,30m", "40km,15m", "60km,30m"]
s=scenario_names[2]
for s in scenario_names
    println("\n\n==================== Running scenario: ", s, " ====================")
    if s == "40km,30m"
        params=set_problem(;max_range    = 40.0, charge_time  = 30.0)
    elseif s == "40km,15m"
        params=set_problem(;max_range    = 40.0, charge_time  = 15.0)
    elseif s == "60km,30m"
        params=set_problem(;max_range    = 60.0, charge_time  = 30.0)
    end



    snaps = Snapshot[]
    t0 = time()   # pipeline start time
    # sanity_checks(locations, dist, params)

    ###########################################
    #Block 2: Initial Charging Stations
    ###########################################

    CW=clarke_wright_WO_CH(dist, params)
    CW_sol=make_solution(CW,collect(2:99),dist,params)
    push!(snaps, Snapshot(elapsed(t0), "Initial Clarke-Wright Without Charging Constraints",CW_sol))
    lower_bound, _, _ = alns_WO_CH(CW, dist, params, verbose=true)
    push!(snaps, Snapshot(elapsed(t0), "Initial ALNS Without Charging Constraints",lower_bound))
    routes=lower_bound.routes
    scores=violation_score(dist, params, routes)
    initial_stations = sortperm(scores; rev = true)[1:5]
    initial_charger_print(initial_stations, params)
    # routes_n=nearest_neighbor_routes(dist, params)
    # scores_n=violation_score(dist, params, routes_n)
    # initial_stations_n = sortperm(scores_n; rev = true)[1:5]
    # initial_charger_print(initial_stations_n, params)

    ##########################################
    #Block 3: Initial Route Construction
    ##########################################
    initial_routes=clarke_wright(dist, initial_stations,params)
    CW_sol_1=make_solution(initial_routes,initial_stations,dist,params)
    push!(snaps, Snapshot(elapsed(t0), "Clarke-Wright With 5 high-scored Chargers",CW_sol_1))
    # routes_n=clarke_wright(dist, initial_stations_n, params)
    # stations=initial_stations;verbose= true
    alns_sol, history_best, history_current = alns(initial_routes, initial_stations, dist, params, verbose=true)
    push!(snaps, Snapshot(elapsed(t0), "ALNS With 5 high-scored Chargers",alns_sol))

    print_solution(alns_sol.routes, initial_stations, dist, params,
                label = "ALNS SOLUTION — $(alns_sol.n_vehicles) vehicles")

    #############################################
    #Block 4: Charger Local Search
    #############################################
    charger_iter_max=5
    charger_iter=0
    best_stations=0; best_sol=0
    while charger_iter<charger_iter_max
        charger_iter+=1
        println("\n=== Charger Local Search Iteration: ", charger_iter, " ===")
        snaps,new_stations, new_sol=charger_local_search(t0,snaps,alns_sol, initial_stations, dist, params, max_iter=30, verbose=true)
        if new_stations==initial_stations
            println("No improvement found, stopping local search.")
            best_stations=initial_stations; best_sol=alns_sol
            break
        else
            initial_stations=new_stations
            println("New stations: ", initial_stations)
            alns_sol, history_best, history_current = alns(new_sol.routes, initial_stations, dist, params, verbose=true)
            push!(snaps, Snapshot(elapsed(t0), "ALNS With high number of iterations",alns_sol))
            print_solution(alns_sol.routes, initial_stations, dist, params,
            label = "ALNS SOLUTION — $(alns_sol.n_vehicles) vehicles")
        end
    end
    push!(snaps, Snapshot(elapsed(t0), "Final ALNS Solution with Local Search",best_sol))

    # best_stations, best_sol=charger_local_search(alns_sol, initial_stations, dist, params)
    # best_sol=alns_sol
    BSON.@save "$(s).bson" best_stations best_sol alns_sol snaps
    # BSON.@load "final_solution_60km.bson" best_stations best_sol alns_sol
    # s="40km,30m"
    # BSON.@load "$(s).bson" best_stations best_sol alns_sol snaps
    
    print_solution(alns_sol.routes, best_stations, dist, params,
                    label = "ALNS SOLUTION — $(alns_sol.n_vehicles) vehicles") 
    #USE visualize_solution FUNCTION TO PLOT THE FINAL SOLUTION
    # visualize_solution(
    #     alns_sol.routes, best_stations, locations, dist, params,
    #     label = "Final ALNS Solution with Local Search",
    #     filename = "final_solution_60km.png"
    # )

    Vis_Sol(
        alns_sol, best_stations, locations, dist, params;
        label = "Final ALNS Solution with Local Search",
        filename = "$(s)"
    )

    [s.elapsed_sec for s in snaps][end]
    [s.sol.n_vehicles for s in snaps]
    [s.description for s in snaps], [s.solution.n_vehicles for s in snaps]
end


# BSON.@load "final_solution.bson" best_stations best_sol alns_sol
# print_solution(alns_sol.routes, best_stations, dist, params,
#                 label = "ALNS SOLUTION — $(alns_sol.n_vehicles) vehicles")

# BSON.@load "final_solution_60km.bson" best_stations best_sol alns_sol
# print_solution(alns_sol.routes, best_stations, dist, params,
#                 label = "ALNS SOLUTION — $(alns_sol.n_vehicles) vehicles")
