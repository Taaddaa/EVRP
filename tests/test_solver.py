"""Tests for evrp.solver (GreedySolver)."""

import os
import pytest
from evrp.instance import EVRPInstance
from evrp.solver import GreedySolver
from evrp.models import (
    ChargingStation,
    Customer,
    Depot,
    Solution,
    Vehicle,
)


SAMPLE_FILE = os.path.join(
    os.path.dirname(__file__), "..", "data", "sample.evrp"
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_tiny_instance():
    """One depot, one customer (d=5 from depot), one charging station.
    Vehicle battery=60, max_load=100 – trivially feasible.
    """
    depot = Depot(node_id=0, x=0.0, y=0.0)
    customer = Customer(node_id=1, x=3.0, y=4.0, demand=20.0)
    station = ChargingStation(node_id=2, x=6.0, y=0.0)
    vehicle = Vehicle(vehicle_id=0, max_load=100.0, battery_capacity=60.0)
    return EVRPInstance(
        name="tiny",
        depot=depot,
        customers=[customer],
        charging_stations=[station],
        vehicles=[vehicle],
    )


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


def test_solver_serves_all_customers_tiny():
    inst = _make_tiny_instance()
    solver = GreedySolver(inst)
    solution = solver.solve()

    served = set()
    for route in solution.routes:
        for node in route.nodes:
            if node.node_type.value == "customer":
                served.add(node.node_id)

    assert served == {c.node_id for c in inst.customers}


def test_solver_routes_start_and_end_at_depot_tiny():
    inst = _make_tiny_instance()
    solution = GreedySolver(inst).solve()
    for route in solution.routes:
        assert route.nodes[0].node_type.value == "depot"
        assert route.nodes[-1].node_type.value == "depot"


def test_solver_solution_feasible_tiny():
    inst = _make_tiny_instance()
    solution = GreedySolver(inst).solve()
    assert solution.is_feasible is True


def test_solver_solution_positive_distance_tiny():
    inst = _make_tiny_instance()
    solution = GreedySolver(inst).solve()
    assert solution.total_distance > 0


def test_solver_sample_instance_serves_all_customers():
    inst = EVRPInstance.from_file(SAMPLE_FILE)
    solver = GreedySolver(inst)
    solution = solver.solve()

    served = set()
    for route in solution.routes:
        for node in route.nodes:
            if node.node_type.value == "customer":
                served.add(node.node_id)

    expected = {c.node_id for c in inst.customers}
    assert served == expected


def test_solver_sample_instance_routes_start_end_depot():
    inst = EVRPInstance.from_file(SAMPLE_FILE)
    solution = GreedySolver(inst).solve()
    for route in solution.routes:
        assert route.nodes[0].node_type.value == "depot"
        assert route.nodes[-1].node_type.value == "depot"


def test_solver_sample_instance_feasible():
    inst = EVRPInstance.from_file(SAMPLE_FILE)
    solution = GreedySolver(inst).solve()
    assert solution.is_feasible is True


def test_solver_no_customers_returns_empty_solution():
    depot = Depot(node_id=0, x=0.0, y=0.0)
    vehicle = Vehicle(vehicle_id=0, max_load=100.0, battery_capacity=60.0)
    inst = EVRPInstance(
        name="empty",
        depot=depot,
        customers=[],
        charging_stations=[],
        vehicles=[vehicle],
    )
    solution = GreedySolver(inst).solve()
    assert solution.routes == []
    assert solution.total_distance == 0.0
