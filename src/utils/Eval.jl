function build_dist_matrix(locations::Matrix{Float64})
    n = size(locations, 1)
    dist = zeros(Float64, n, n)
    for i in 1:n
        for j in 1:n
            dx = locations[i,1] - locations[j,1]
            dy = locations[i,2] - locations[j,2]
            dist[i,j] = sqrt(dx^2 + dy^2)
        end
    end
    return dist
end

function route_travel_time(route::Vector{Int}, dist::Matrix{Float64}, params::Params)
    total = 0.0
    for k in 1:length(route)-1
        total += dist[route[k], route[k+1]] / params.speed * 60.0
    end
    return total
end

function route_travel_dist(route::Vector{Int}, dist::Matrix{Float64})
    total = 0.0
    for k in 1:length(route)-1
        total += dist[route[k], route[k+1]]
    end
    return total
end


function check_solution_feasible(
    routes   ::Vector{Vector{Int}},
    stations ::Vector{Int},
    dist     ::Matrix{Float64},
    params   ::Params
)
    all_feasible = true
    total_time   = 0.0

    for route in routes
        _, t, feasible = insert_charging_stops(route, stations, dist, params)
        total_time += t
        if !feasible
            all_feasible = false
        end
    end

    return all_feasible, length(routes), total_time
end


function solution_cost(
    routes   ::Vector{Vector{Int}},
    stations ::Vector{Int},
    dist     ::Matrix{Float64},
    params   ::Params
)
    n_vehicles   = length(routes)
    total_dist   = 0.0

    for route in routes
        new_route, _, feasible = insert_charging_stops(route, stations, dist, params)
        if feasible
            total_dist += route_travel_dist(new_route, dist)
        else
            total_dist += 1e9    # heavy penalty for infeasible route
        end
    end

    # Lexicographic cost: vehicles first, distance second
    # Encode as: vehicles * big_number + distance
    return n_vehicles * 10000.0 + total_dist
end

# function count_vehicles(routes::Vector{Vector{Int}})
#     return length(routes)
# end

function total_distance(
    routes   ::Vector{Vector{Int}},
    stations ::Vector{Int},
    dist     ::Matrix{Float64},
    params   ::Params
)
    total = 0.0
    for route in routes
        new_route, _, _ = insert_charging_stops(route, stations, dist, params)
        total += route_travel_dist(new_route, dist)
    end
    return total
end

function make_solution(
    routes  ::Vector{Vector{Int}},
    stations::Vector{Int},
    dist    ::Matrix{Float64},
    params  ::Params
)
    cost       = solution_cost(routes, stations, dist, params)
    n_vehicles = length(routes)
    total_dist = total_distance(routes, stations, dist, params)
    return Solution(routes, cost, n_vehicles, total_dist)
end

function violation_score(dist::Matrix{Float64}, params::Params,routes::Vector{Vector{Int}})

    scores = zeros(Float64, params.n_customers + 1)  # index = location index

    for route in routes
        cum_range = 0.0
        for k in 1:length(route)-1
            i   = route[k]
            j   = route[k+1]
            leg = dist[i,j]

            if cum_range + leg > params.max_range
                # Violation! Score all customers that could help
                for s in 2:params.n_customers+1
                    # Can s be inserted between i and j?
                    if dist[i,s] <= params.max_range - cum_range &&
                       dist[s,j] <= params.max_range
                        scores[s] += 1.0 *1e6+ dist[i,j] - dist[i,s] - dist[s,j]  # more score for bigger violation
                    end
                end
                cum_range = leg   # pretend we charged here
            else
                cum_range += leg
            end
        end
    end

    return scores
end

function select_operator(weights::Vector{Float64})
    # Roulette wheel selection
    total = sum(weights)
    r     = rand() * total
    cum   = 0.0
    for (i, w) in enumerate(weights)
        cum += w
        cum >= r && return i
    end
    return length(weights)
end