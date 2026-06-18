"""Tests for evrp.models."""

import pytest
from evrp.models import (
    ChargingStation,
    Customer,
    Depot,
    Node,
    NodeType,
    Route,
    Solution,
    Vehicle,
)


def test_depot_type():
    depot = Depot(node_id=0, x=0.0, y=0.0)
    assert depot.node_type == NodeType.DEPOT


def test_customer_type_and_demand():
    c = Customer(node_id=1, x=10.0, y=20.0, demand=25.0)
    assert c.node_type == NodeType.CUSTOMER
    assert c.demand == 25.0


def test_customer_default_demand():
    c = Customer(node_id=2, x=5.0, y=5.0)
    assert c.demand == 0.0


def test_charging_station_type():
    cs = ChargingStation(node_id=3, x=15.0, y=15.0)
    assert cs.node_type == NodeType.CHARGING_STATION


def test_vehicle_initial_battery():
    v = Vehicle(vehicle_id=0, max_load=100.0, battery_capacity=60.0)
    assert v.initial_battery == 60.0


def test_vehicle_consumption_rate_default():
    v = Vehicle(vehicle_id=0, max_load=100.0, battery_capacity=60.0)
    assert v.consumption_rate == 1.0


def test_route_repr():
    depot = Depot(node_id=0, x=0.0, y=0.0)
    vehicle = Vehicle(vehicle_id=0, max_load=100.0, battery_capacity=60.0)
    route = Route(vehicle=vehicle, nodes=[depot, depot])
    assert "Route(" in repr(route)


def test_solution_total_distance_empty():
    sol = Solution()
    assert sol.total_distance == 0.0
    assert sol.is_feasible is True


def test_solution_total_distance_sum():
    vehicle = Vehicle(vehicle_id=0, max_load=100.0, battery_capacity=60.0)
    depot = Depot(node_id=0, x=0.0, y=0.0)
    r1 = Route(vehicle=vehicle, nodes=[depot, depot], total_distance=10.0, is_feasible=True)
    r2 = Route(vehicle=vehicle, nodes=[depot, depot], total_distance=20.0, is_feasible=True)
    sol = Solution(routes=[r1, r2])
    assert sol.total_distance == 30.0
    assert sol.is_feasible is True


def test_solution_infeasible_if_any_route_infeasible():
    vehicle = Vehicle(vehicle_id=0, max_load=100.0, battery_capacity=60.0)
    depot = Depot(node_id=0, x=0.0, y=0.0)
    r1 = Route(vehicle=vehicle, nodes=[depot, depot], total_distance=10.0, is_feasible=True)
    r2 = Route(vehicle=vehicle, nodes=[depot, depot], total_distance=20.0, is_feasible=False)
    sol = Solution(routes=[r1, r2])
    assert sol.is_feasible is False
