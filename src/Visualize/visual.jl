# # ============================================================
# #  SECTION 4B: VISUALIZATION
# # ============================================================

# using Plots

# function visualize_solution(
#     routes   ::Vector{Vector{Int}},
#     stations ::Vector{Int},
#     locations::Matrix{Float64},
#     dist     ::Matrix{Float64},
#     params   ::Params;
#     label    ::String = "Clarke-Wright Solution"
# )
#     # Color palette for routes
#     route_colors = [:blue, :green, :orange, :purple, :brown, :pink, 
#                     :cyan, :magenta, :olive, :teal, :red, :gray]

#     p = plot(
#         title     = label,
#         xlabel    = "X (km)",
#         ylabel    = "Y (km)",
#         legend    = :topright,
#         size      = (900, 850),
#         grid      = true,
#         gridalpha = 0.3,
#         dpi       = 150
#     )

#     # ── Draw routes ──
#     for (idx, route) in enumerate(routes)
#         color = route_colors[mod1(idx, length(route_colors))]

#         # Get route with charging stops inserted
#         new_route, t, feasible = insert_charging_stops(route, stations, dist, params)

#         # Draw edges
#         for k in 1:length(new_route)-1
#             i = new_route[k]
#             j = new_route[k+1]
#             plot!(p,
#                 [locations[i,1], locations[j,1]],
#                 [locations[i,2], locations[j,2]],
#                 color     = color,
#                 linewidth = 1.5,
#                 alpha     = 0.6,
#                 label     = k == 1 ? "Route $idx ($(length(route)-2) cust, $(round(t,digits=1))min)" : ""
#             )
#         end
#     end

#     # ── Plot regular customers ──
#     regular = [i for i in 2:99 if i ∉ stations]
#     scatter!(p,
#         locations[regular, 1],
#         locations[regular, 2],
#         marker    = :circle,
#         markersize= 5,
#         color     = :lightblue,
#         markerstrokecolor = :steelblue,
#         markerstrokewidth = 1,
#         label     = "Customers ($(length(regular)))"
#     )

#     # ── Plot charging stations ──
#     scatter!(p,
#         locations[stations, 1],
#         locations[stations, 2],
#         marker    = :star5,
#         markersize= 14,
#         color     = :yellow,
#         markerstrokecolor = :orange,
#         markerstrokewidth = 2,
#         label     = "Charging Stations ($(length(stations)))"
#     )

#     # ── Label charging stations ──
#     for s in stations
#         annotate!(p,
#             locations[s,1] + 0.4,
#             locations[s,2] + 0.4,
#             text("⚡C$(s-1)", 7, :orange, :left)
#         )
#     end

#     # ── Plot depot ──
#     scatter!(p,
#         [locations[1,1]],
#         [locations[1,2]],
#         marker    = :rect,
#         markersize= 12,
#         color     = :red,
#         markerstrokecolor = :darkred,
#         markerstrokewidth = 2,
#         label     = "Depot"
#     )
#     annotate!(p,
#         locations[1,1] + 0.4,
#         locations[1,2] + 0.4,
#         text("DEPOT", 8, :darkred, :left, :bold)
#     )

#     # ── Plot origin (0,0) ──
#     scatter!(p,
#         [0.0], [0.0],
#         marker    = :diamond,
#         markersize= 8,
#         color     = :black,
#         label     = "Origin (0,0)"
#     )
#     annotate!(p, 0.5, 0.5, text("(0,0)", 7, :black, :left))

#     # ── Summary box ──
#     n_vehicles = length(routes)
#     total_dist = sum(route_travel_dist(
#                     insert_charging_stops(r, stations, dist, params)[1],
#                     dist) for r in routes)
#     n_charges  = sum(count(n -> n in stations,
#                     insert_charging_stops(r, stations, dist, params)[1])
#                     for r in routes)

#     annotate!(p, 1.0, 29.0,
#         text("Vehicles: $n_vehicles | Total dist: $(round(total_dist,digits=1)) km | Charge stops: $n_charges",
#              8, :black, :left)
#     )

#     display(p)
#     savefig(p, "evrp_solution.png")
#     println("\n✓ Plot saved to evrp_solution.png")
#     return p
# end

# # ============================================================
# #  Run visualization
# # ============================================================

# test_stations = [5, 20, 40, 60, 80]
# visualize_solution(cw_routes, test_stations, locations, dist, params,
#                    label = "Clarke-Wright Solution (6 vehicles, dummy stations)")
 

# ============================================================
#  SECTION 4B: VISUALIZATION
# ============================================================
#best_stations= [75, 63, 10, 45, 9]
# visualize_solution(
#     routes   ::Vector{Vector{Int}},
#     best_stations ::Vector{Int},
#     locations::Matrix{Float64},
#     dist     ::Matrix{Float64},
#     params   ::Params;
# )
function visualize_solution(
    routes   ::Vector{Vector{Int}},
    stations ::Vector{Int},
    locations::Matrix{Float64},
    dist     ::Matrix{Float64},
    params   ::Params;
    label    ::String = "Final_Solution",
    filename ::String = "evrp_solution.png"
)
    # Color palette for routes
    route_colors = [:blue, :green, :orange, :purple, :brown, :pink,
                    :cyan, :magenta, :olive, :teal, :red, :gray]

    p = plot(
        title     = label,
        xlabel    = "X (km)",
        ylabel    = "Y (km)",
        legend    = :topright,
        size      = (1100, 1000),
        grid      = true,
        gridalpha = 0.3,
        dpi       = 150
    )

    # ── Draw routes ──
    for (idx, route) in enumerate(routes)
        color = route_colors[mod1(idx, length(route_colors))]

        # Get route with charging stops inserted
        new_route, t, feasible = insert_charging_stops(route, stations, dist, params)

        # Draw edges
        for k in 1:length(new_route)-1
            i = new_route[k]
            j = new_route[k+1]
            plot!(p,
                [locations[i,1], locations[j,1]],
                [locations[i,2], locations[j,2]],
                color     = color,
                linewidth = 1.5,
                alpha     = 0.6,
                label     = k == 1 ? "Route $idx ($(length(route)-2) cust, $(round(t,digits=1))min)" : ""
            )
        end
    end

    # ── Plot regular customers ──
    regular = [i for i in 2:99 if i ∉ stations]
    scatter!(p,
        locations[regular, 1],
        locations[regular, 2],
        marker            = :circle,
        markersize        = 6,
        color             = :lightblue,
        markerstrokecolor = :steelblue,
        markerstrokewidth = 1,
        label             = "Customers ($(length(regular)))"
    )

    # ── Customer number labels ──
    for i in regular
        annotate!(p,
            locations[i,1] + 0.25,
            locations[i,2] + 0.25,
            text("$(i-1)", 5, :black, :left)   # i-1 converts to customer number
        )
    end

    # ── Plot charging stations ──
    scatter!(p,
        locations[stations, 1],
        locations[stations, 2],
        marker            = :star5,
        markersize        = 14,
        color             = :yellow,
        markerstrokecolor = :orange,
        markerstrokewidth = 2,
        label             = "Charging Stations ($(length(stations)))"
    )

    # ── Label charging stations ──
    for s in stations
        annotate!(p,
            locations[s,1] + 0.25,
            locations[s,2] + 0.25,
            text("$(s-1)", 7, :orange, :left, :bold)
        )
    end

    # ── Plot depot ──
    scatter!(p,
        [locations[1,1]],
        [locations[1,2]],
        marker            = :rect,
        markersize        = 12,
        color             = :red,
        markerstrokecolor = :darkred,
        markerstrokewidth = 2,
        label             = "Depot"
    )
    annotate!(p,
        locations[1,1] + 0.3,
        locations[1,2] + 0.3,
        text("DEPOT", 8, :darkred, :left, :bold)
    )

    # ── Plot origin (0,0) ──
    scatter!(p,
        [0.0], [0.0],
        marker    = :diamond,
        markersize= 8,
        color     = :black,
        label     = "Origin (0,0)"
    )
    annotate!(p, 0.4, 0.4, text("(0,0)", 7, :black, :left))

    # ── Summary box ──
    n_vehicles = length(routes)
    total_dist = sum(route_travel_dist(
                    insert_charging_stops(r, stations, dist, params)[1],
                    dist) for r in routes)
    n_charges  = sum(count(n -> n in stations,
                    insert_charging_stops(r, stations, dist, params)[1])
                    for r in routes)

    annotate!(p, 0.5, 30.5,
        text("Vehicles: $n_vehicles | Dist: $(round(total_dist,digits=1)) km | Charge stops: $n_charges",
             9, :black, :left, :bold)
    )

    display(p)
    savefig(p, filename)
    println("\n✓ Plot saved to $filename")
    return p
end