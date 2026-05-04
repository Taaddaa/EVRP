struct Params
    # Problem constants
    n_customers  ::Int
    max_range    ::Float64    # km
    max_time     ::Float64    # minutes
    speed        ::Float64    # km/h
    charge_time  ::Float64    # minutes
    n_chargers   ::Int

    # ALNS parameters (Ropke & Pisinger 2006)
    max_iter     ::Int
    reduced_iter   ::Int
    segment_size ::Int
    reduced_segment_size ::Int
    decay        ::Float64    # ρ operator weight decay
    sigma1       ::Float64    # reward: new global best
    sigma2       ::Float64    # reward: better than current
    sigma3       ::Float64    # reward: accepted not better
    removal_min  ::Int        # min customers removed per destroy
    removal_max  ::Int        # max customers removed per destroy

    # SA parameters (auto-calculated later)
    T_start      ::Float64
    T_end        ::Float64
    cooling_rate ::Float64
    
end

struct Saving
    i    ::Int
    j    ::Int
    value::Float64
end

mutable struct RouteTracker
    routes      ::Vector{Vector{Int}}   # all current routes
    route_of    ::Vector{Int}           # route_of[i] = route index for customer i
    is_interior ::Vector{Bool}          # interior[i] = true if i is not at route end
end

mutable struct Solution
    routes    ::Vector{Vector{Int}}
    cost      ::Float64
    n_vehicles::Int
    total_dist::Float64
end

mutable struct WeightManager
    # Operator names
    destroy_names ::Vector{String}
    repair_names  ::Vector{String}

    # Weights (updated each segment)
    destroy_weights::Vector{Float64}
    repair_weights ::Vector{Float64}

    # Segment scores and usage counts
    destroy_scores ::Vector{Float64}
    repair_scores  ::Vector{Float64}
    destroy_counts ::Vector{Int}
    repair_counts  ::Vector{Int}

    # Hyperparameters
    decay  ::Float64
    sigma1 ::Float64    # new global best
    sigma2 ::Float64    # better than current
    sigma3 ::Float64    # accepted not better
end

struct Snapshot
    elapsed_sec  ::Float64          # wall-clock time since pipeline start
    stage_label  ::String           
    sol       :: Solution  
end