# ============================================================
#  E-VRP Visualization with CairoMakie
#  98 Customers · 5 Vehicles · 5 Charging Stations · 1 Depot
# ============================================================
using CairoMakie
using Statistics

# sol=alns_sol
function Vis_Sol(sol, chargers, locations, dist, params;
    label = "Final Solution",
    filename = "Unnamed")
    
    routes=sol.routes
    # chargers= best_stations
    N_CUSTOMERS  = params.n_customers
    N_VEHICLES   = sol.n_vehicles
    N_CHARGERS   = params.n_chargers
    # Summarise
    println("Route sizes: ", length.(routes))

    # ─────────────────────────────────────────────────────────────
    # 3.  COLOUR PALETTE  (LIST-inspired)
    # ─────────────────────────────────────────────────────────────
    vehicle_colors = [
        colorant"#FF3CAC",   # hot pink / magenta
        colorant"#BF5AF2",   # vivid purple
        # colorant"#F9C74F",   # vivid yellow
        colorant"#43E8A0",   # neon mint-green
        colorant"#4CC9F0",   # electric sky-blue
        colorant"#FF6B35",   # bright orange
        colorant"#FF6688",   # flamingo punch
        colorant"#FF3300",   # lava red
        colorant"#33FFCC",   # mint laser
    ]

    total_dist = sol.total_dist
    # ─────────────────────────────────────────────────────────────
    # 4.  FIGURE SETUP
    scale_factor = 1  # for HiDPI export; set to 1 for normal resolution
    font_factor = 1.2 * scale_factor
    # ─────────────────────────────────────────────────────────────
    fig = Figure(size = (1200, 900).*scale_factor, backgroundcolor = :white)

    ax = Axis(
        fig[1:2, 1],
        # ── Main title (bigger) ───────────────────────────────────
        title       = label,
        titlesize   = 18*font_factor,
        titlecolor  = RGBf(83/255, 121/255, 146/255),
        titlefont   = :bold,
        titlegap        = 4,                                          # space between title and subtitle
        # ── Subtitle (smaller) ───────────────────────────────────
        subtitle        = "Vehicles: $N_VEHICLES | Dist: $(round(total_dist, digits=1)) km",
        subtitlesize    = 14 * font_factor,
        subtitlecolor   = RGBf(0.35, 0.35, 0.35),
        subtitlefont    = :regular,
        xlabel      = "X Coordinate",
        ylabel      = "Y Coordinate",
        xlabelsize  = 13*font_factor,
        ylabelsize  = 13*font_factor,
        xgridcolor  = RGBAf(0.85, 0.85, 0.85, 0.6),
        ygridcolor  = RGBAf(0.85, 0.85, 0.85, 0.6),
        # backgroundcolor = RGBf(0.07, 0.07, 0.12)   # deep navy-black,
    )

    # ─────────────────────────────────────────────────────────────
    # 5.  DRAW ROUTES  (depot → customers → depot)
    # ─────────────────────────────────────────────────────────────
    for (v, route) in enumerate(routes)
        isempty(route) && continue
        col = vehicle_colors[v]

        # Build full path: depot → route → depot
        xs = locations[route,1]
        ys = locations[route,2]

        lines!(ax, xs, ys;
            color     = (col, 0.55),
            linewidth = 1.8,
            linestyle = :solid,
        )

        # Arrows on each segment to show direction
        for i in 1:length(xs)-1
            dx = xs[i+1] - xs[i]
            dy = ys[i+1] - ys[i]
            mid_x = xs[i] + 0.5dx
            mid_y = ys[i] + 0.5dy
            arrows!(ax, [mid_x], [mid_y], [dx*0.12], [dy*0.12];
                color      = (col, 0.8),
                arrowsize  = 8,
                linewidth  = 0,
            )
        end
    end

    # ─────────────────────────────────────────────────────────────
    # 6.  DRAW CUSTOMERS
    # ─────────────────────────────────────────────────────────────
    # colour each dot by the vehicle that serves it
    dot_colors = Vector{Any}(undef, N_CUSTOMERS)
    for (v, route) in enumerate(routes)
        for i in route
            if i!=1
                dot_colors[i-1] = vehicle_colors[v]
            end
        end
    end

    scatter!(ax, locations[2:end,1], locations[2:end,2];
        color      = dot_colors,
        marker     = :circle,
        markersize = 14*font_factor,
        strokewidth = 0.8,
        strokecolor = :white,
    )

    # Customer index labels (small, subtle)
    for i in 1:N_CUSTOMERS
        text!(ax, locations[i+1,1]-0.25, locations[i+1,2]+0.25;
            text     = string(i),
            fontsize = 10*font_factor,
            color    = RGBAf(0.3, 0.3, 0.3, 0.8),
            align    = (:left, :bottom),
        )
    end

    # ─────────────────────────────────────────────────────────────
    # 7.  DRAW CHARGING STATIONS
    # ─────────────────────────────────────────────────────────────
    for idx in chargers
        # # Glowing halo
        scatter!(ax, [locations[idx,1]], [locations[idx,2]];
            color      = (colorant"#FFE566", 1),
            marker     = :circle,
            markersize = 14*font_factor,
        )
        # Charger symbol (⚡ as text marker)
        scatter!(ax, [locations[idx,1]], [locations[idx,2]];
            color      = colorant"#9D0208",
            # font = "Bold",
            marker     = '⚡',
            markersize = 26,
        )
    end

    # ─────────────────────────────────────────────────────────────
    # 8.  DRAW DEPOT
    # ─────────────────────────────────────────────────────────────
    # Outer ring
    scatter!(ax, [locations[1,1]], [locations[1,2]];
        color      = (colorant"#000000", 0.15),
        marker     = :circle,
        markersize = 30,
    )
    # Filled star
    scatter!(ax, [locations[1,1]], [locations[1,2]];
        color      = colorant"#000000",
        marker     = '★',
        markersize = 22,
    )
    text!(ax, locations[1,1], locations[1,2];
        text     = "Depot",
        fontsize = 11*font_factor,
        color    = :black,
        font     = :bold,
        align    = (:center, :top),
    )

    # ─────────────────────────────────────────────────────────────
    # 9.  LEGEND
    # ─────────────────────────────────────────────────────────────
    legend_elements = [
        # One entry per vehicle
        [LineElement(color = vehicle_colors[v], linewidth = 2.5),
        MarkerElement(color = vehicle_colors[v], marker = :circle, markersize = 10)]
        for v in 1:N_VEHICLES
    ]

    legend_labels = ["Vehicle $v  ($(length(routes[v])) stops)" for v in 1:N_VEHICLES]

    # Depot & charger entries
    push!(legend_elements, [MarkerElement(color = :black, marker = '★', markersize = 14)])
    push!(legend_labels,   "Depot")
    if N_CHARGERS!=0 push!(legend_elements, [MarkerElement(color = colorant"#9D0208", marker = '⚡', markersize = 18)]) end
    if N_CHARGERS!=0 push!(legend_labels,   "Charging Station (×$(N_CHARGERS))") end

    Legend(
        fig[1, 2],
        legend_elements,
        legend_labels;
        framecolor  = RGBf(83/255, 121/255, 146/255),
        framewidth  = 1.2,
        labelsize   = 12*font_factor,
        titlesize   = 13*font_factor,
        title       = "Legend",
        titlefont   = :bold,
        titlecolor  = RGBf(83/255, 121/255, 146/255),
        padding     = (12, 12, 12, 12),
        rowgap      = 6,
        patchsize   = (25, 18),
    )

    # dists = [route_distance(routes[v], customer_x, customer_y, depot) for v in 1:N_VEHICLES]

    # stats_text = join([
    #     "── Route Statistics ──",
    #     "",
    #     (["Veh $v:  $(length(routes[v])) stops,  dist=$(round(dists[v]; digits=1))"
    #     for v in 1:N_VEHICLES])...,
    #     "",
    #     "Total distance : $(round(sum(dists); digits=1))",
    #     "Avg / vehicle  : $(round(mean(dists); digits=1))",
    #     "Charger nodes  : $(N_CHARGERS)",
    # ], "\n")

    # Label(
    #     fig[2, 2],
    #     stats_text;
    #     font       = :regular,
    #     fontsize   = 11*font_factor,
    #     color      = RGBf(0.1, 0.1, 0.1),
    #     halign     = :left,
    #     valign     = :top,
    #     padding    = (12, 12, 12, 12),
    #     tellheight = false,
    # )

    if !isempty(chargers)
        station_lines = ["Charging stations:"]
        for idx in chargers
            push!(station_lines, "  ⚡  C$(idx-1)  ($(round(locations[idx,1], digits=1)), $(round(locations[idx,2], digits=1)))")
        end
        Label(
            fig[2, 2],
            join(station_lines, "\n");
            font          = :regular,
            fontsize      = 11 * font_factor,
            color         = colorant"#9D0208",
            halign        = :left,
            valign        = :top,
            justification = :left,
            padding       = (14, 14, 8, 8),
            tellheight    = false,
            tellwidth     = false,
        )
    end


    # ─────────────────────────────────────────────────────────────
    # 12.  LAYOUT TUNING & SAVE
    # ─────────────────────────────────────────────────────────────
    colsize!(fig.layout, 1, Relative(0.78))   # map takes 78 % of width
    rowsize!(fig.layout, 1, Relative(0.93))

    save("Plots/$filename.png", fig; px_per_unit = 2)  # 2× for HiDPI
    display(fig)

    println("\n✓ Figure saved as  $filename.png")
end

# function route_distance(route, cx, cy, depot)
#     isempty(route) && return 0.0
#     d  = hypot(cx[route[1]] - depot[1], cy[route[1]] - depot[2])
#     for i in 2:length(route)
#         d += hypot(cx[route[i]] - cx[route[i-1]], cy[route[i]] - cy[route[i-1]])
#     end
#     d += hypot(depot[1] - cx[route[end]], depot[2] - cy[route[end]])
#     return d
# end