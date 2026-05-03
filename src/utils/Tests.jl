
function sanity_checks(locations, dist, params)
    n = size(locations, 1)

    println("=" ^ 50)
    println("  E-VRP SOLVER — SANITY CHECKS")
    println("=" ^ 50)

    println("\n📍 NODES")
    @printf("  Total nodes (depot + customers): %d\n", n)
    @printf("  Depot location: (%.3f, %.3f)\n", locations[1,1], locations[1,2])
    @printf("  First customer: (%.3f, %.3f)\n", locations[2,1], locations[2,2])
    @printf("  Last customer:  (%.3f, %.3f)\n", locations[n,1], locations[n,2])

    println("\n📏 DISTANCE MATRIX")
    @printf("  Matrix size: %dx%d\n", n, n)
    @printf("  Depot → Customer 1:  %.3f km\n", dist[1,2])
    @printf("  Depot → Customer 98: %.3f km\n", dist[1,n])
    @printf("  Max distance:        %.3f km\n", maximum(dist))
    @printf("  Avg distance:        %.3f km\n", sum(dist)/(n*(n-1)))
    @printf("  Symmetric check:     %s\n", dist == dist' ? "✓ PASS" : "✗ FAIL")
    @printf("  Zero diagonal check: %s\n", all(dist[i,i]==0 for i in 1:n) ? "✓ PASS" : "✗ FAIL")

    println("\n⚙️  PARAMETERS")
    @printf("  Max range:    %.1f km\n",  params.max_range)
    @printf("  Max time:     %.1f min\n", params.max_time)
    @printf("  Speed:        %.1f km/h\n", params.speed)
    @printf("  Charge time:  %.1f min\n", params.charge_time)
    @printf("  N chargers:   %d\n",       params.n_chargers)

    println("\n🌡️  SA TEMPERATURES")
    @printf("  T_start:      %.6f\n", params.T_start)
    @printf("  T_end:        %.6f\n", params.T_end)
    @printf("  Cooling rate: %.6f\n", params.cooling_rate)

    # Critical check: are any single legs already > max_range?
    long_legs = 0
    for i in 2:n
        for j in 2:n
            if i != j && dist[i,j] > params.max_range
                long_legs += 1
            end
        end
    end
    println("\n⚠️  RANGE ANALYSIS")
    @printf("  Customer pairs > %.0f km: %d\n", params.max_range, long_legs)
    @printf("  (These pairs NEED a charging stop between them)\n")

    # Max time budget in km equivalent
    max_km = params.max_time / 60.0 * params.speed
    @printf("  Max km per vehicle (no charging): %.1f km\n", max_km)
    @printf("  Max km per vehicle (1 charge):    %.1f km\n",
            max_km - params.charge_time/60.0*params.speed)

    println("\n" * "=" ^ 50)
    println("  All checks passed ✓ Ready to solve!")
    println("=" ^ 50)
end

function test_charging_insertion(dist, params)
    println("\n" * "=" ^ 50)
    println("  SECTION 3 TESTS — Charging Insertion")
    println("=" ^ 50)

    # Use 5 dummy stations for testing
    # (will be replaced by real placement in Section 6)
    test_stations = [5, 20, 40, 60, 80]   # customer indices+1

    # Test 1: short route — should need no charging
    route1 = [1, 10, 15, 30, 1]
    r1, t1, f1 = insert_charging_stops(route1, test_stations, dist, params)
    println("\nTest 1 — Short route (should be feasible, no charge):")
    @printf("  Route: %s\n", string(route1))
    @printf("  Time: %.1f min | Feasible: %s\n", t1, f1 ? "✓" : "✗")

    # Test 2: long route — may need charging
    route2 = [1, 3, 68, 19, 36, 48, 65, 1]
    r2, t2, f2 = insert_charging_stops(route2, test_stations, dist, params)
    println("\nTest 2 — Longer route (may need charge):")
    @printf("  Original:  %s\n", string(route2))
    @printf("  With stops: %s\n", string(r2))
    @printf("  Time: %.1f min | Feasible: %s\n", t2, f2 ? "✓" : "✗")

    # Test 3: single customer — trivial
    route3 = [1, 25, 1]
    r3, t3, f3 = insert_charging_stops(route3, test_stations, dist, params)
    println("\nTest 3 — Single customer:")
    @printf("  Route: %s\n", string(route3))
    @printf("  Time: %.1f min | Feasible: %s\n", t3, f3 ? "✓" : "✗")

    # Test 4: cost function
    routes_test = [route1, route2, route3]
    cost = solution_cost(routes_test, test_stations, dist, params)
    println("\nTest 4 — Solution cost:")
    @printf("  Vehicles: %d | Cost: %.2f\n", length(routes_test), cost)

    println("\n" * "=" ^ 50)
    println("  Section 3 tests complete ✓")
    println("=" ^ 50)
end
 

function test_clarke_wright(dist, params)
    println("\n" * "=" ^ 55)
    println("  SECTION 4 TESTS — Clarke-Wright")
    println("=" ^ 55)

    # Dummy stations for now (Section 6 will find real ones)
    test_stations = [5, 20, 40, 60, 80]

    println("\nComputing savings...")
    savings = compute_savings(dist, params)
    @printf("  Total savings computed: %d\n", length(savings))
    @printf("  Top 3 savings:\n")
    for s in savings[1:3]
        @printf("    s(C%d, C%d) = %.3f\n", s.i-1, s.j-1, s.value)
    end

    println("\nRunning Clarke-Wright...")
    routes = clarke_wright(dist, test_stations, params)

    # Check all customers covered
    all_customers = Set(2:99)
    visited = Set{Int}()
    for route in routes
        for node in route[2:end-1]
            push!(visited, node)
        end
    end
    missing_customers = setdiff(all_customers, visited)

    @printf("  Routes generated:   %d\n", length(routes))
    @printf("  Customers visited:  %d / 98\n", length(visited))
    @printf("  Missing customers:  %d\n", length(missing_customers))
    length(missing_customers) > 0 && println("  Missing: ", missing_customers)

    print_solution(routes, test_stations, dist, params, label="CLARKE-WRIGHT INITIAL SOLUTION")

    return routes
end

function test_alns(cw_routes, dist, params)
    println("\nRunning ALNS on Clarke-Wright solution...")
    test_stations = [5, 20, 40, 60, 80]

    best_sol, hist_best, hist_current = alns(
        cw_routes, test_stations, dist, params, verbose=true)

    println("\nALNS Result:")
    print_solution(best_sol.routes, test_stations, dist, params,
                   label="ALNS SOLUTION")

    return best_sol
end