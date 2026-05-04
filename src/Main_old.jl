include("utils/packages.jl")

##########################################
#Block 1: Load data, build distance matrix
##########################################

depot= (x=18.190, y=6.320)
params=set_problem(;max_range    = 40.0, charge_time  = 15.0)
Costumer_Data, locations = parse_costumers(pwd()*"/Data/costumers.txt", depot)
dist= build_dist_matrix(locations)

###########################################
#Block 2: Initial Charging Stations
###########################################

CW=clarke_wright_WO_CH(dist, params)
print_routes(CW)
lower_bound, _, _ = alns_WO_CH(CW, dist, params, verbose=true)
routes=lower_bound.routes
scores=violation_score(dist, params, routes)
initial_stations = sortperm(scores; rev = true)[1:5]
initial_charger_print(initial_stations, params)

##########################################
#Block 3: Initial Route Construction
##########################################
initial_routes=clarke_wright(dist, initial_stations,params)
print_routes(initial_routes,"Initial Routes with Charger Insertion")
alns_sol, history_best, history_current = alns(initial_routes, initial_stations, dist, params, verbose=true)
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
    new_stations, new_sol=charger_local_search(alns_sol, initial_stations, dist, params, max_iter=30, verbose=true)
    if new_stations==initial_stations
        println("No improvement found, stopping local search.")
        best_stations=initial_stations; best_sol=alns_sol
        break
    else
        initial_stations=best_stations
        println("New stations: ", initial_stations)
        alns_sol, history_best, history_current = alns(new_sol.routes, initial_stations, dist, params, verbose=true)
        print_solution(alns_sol.routes, initial_stations, dist, params,
        label = "ALNS SOLUTION — $(alns_sol.n_vehicles) vehicles")
    end
end
# best_stations, best_sol=charger_local_search(alns_sol, initial_stations, dist, params)
# best_sol=alns_sol
BSON.@save "final_solution_60km.bson" best_stations best_sol alns_sol snaps
# BSON.@load "final_solution_60km.bson" best_stations best_sol alns_sol
print_solution(alns_sol.routes, best_stations, dist, params,
                label = "ALNS SOLUTION — $(alns_sol.n_vehicles) vehicles") 


Vis_Sol(
    alns_sol, best_stations, locations, dist, params,
    label = "Final ALNS Solution with Local Search",
    filename = "final_s.png"
)

# #USE visualize_solution FUNCTION TO PLOT THE FINAL SOLUTION
# visual.visualize_solution(
#     alns_sol.routes, best_stations, locations, dist, params,
#     label = "Final ALNS Solution with Local Search",
#     filename = "final_solution_60km.png"
# )


# BSON.@load "final_solution_15m.bson" best_stations best_sol alns_sol
# print_solution(alns_sol.routes, best_stations, dist, params,
#                label = "ALNS SOLUTION 15 minutes charging time— $(alns_sol.n_vehicles) vehicles") 
# BSON.@load "final_solution.bson" best_stations best_sol alns_sol
# print_solution(alns_sol.routes, best_stations, dist, params,
#                 label = "ALNS SOLUTION Original Problem— $(alns_sol.n_vehicles) vehicles")

# BSON.@load "final_solution_60km.bson" best_stations best_sol alns_sol
# print_solution(alns_sol.routes, best_stations, dist, params,
#                 label = "ALNS SOLUTION 60km range— $(alns_sol.n_vehicles) vehicles")
