"""Tests for evrp.instance (EVRPInstance)."""

import math
import os
import pytest
from evrp.instance import EVRPInstance
from evrp.models import NodeType, Vehicle, Route


SAMPLE_FILE = os.path.join(
    os.path.dirname(__file__), "..", "data", "sample.evrp"
)


# ---------------------------------------------------------------------------
# Loading from file
# ---------------------------------------------------------------------------


def test_load_sample_instance():
    inst = EVRPInstance.from_file(SAMPLE_FILE)
    assert inst.name == "sample"
    assert len(inst.customers) == 5
    assert len(inst.charging_stations) == 2
    assert len(inst.vehicles) == 3


def test_load_missing_file_raises():
    with pytest.raises(FileNotFoundError):
        EVRPInstance.from_file("nonexistent.evrp")


def test_load_vehicles_have_correct_capacity():
    inst = EVRPInstance.from_file(SAMPLE_FILE)
    for v in inst.vehicles:
        assert v.max_load == 100.0
        assert v.battery_capacity == 60.0
        assert v.consumption_rate == 1.0


def test_depot_is_first_node():
    inst = EVRPInstance.from_file(SAMPLE_FILE)
    assert inst.nodes[0].node_type == NodeType.DEPOT


# ---------------------------------------------------------------------------
# Distance helpers
# ---------------------------------------------------------------------------


def test_distance_depot_to_itself():
    inst = EVRPInstance.from_file(SAMPLE_FILE)
    assert inst.distance(inst.depot, inst.depot) == 0.0


def test_distance_symmetric():
    inst = EVRPInstance.from_file(SAMPLE_FILE)
    c = inst.customers[0]
    d1 = inst.distance(inst.depot, c)
    d2 = inst.distance(c, inst.depot)
    assert math.isclose(d1, d2)


def test_node_by_id():
    inst = EVRPInstance.from_file(SAMPLE_FILE)
    node = inst.node_by_id(0)
    assert node.node_type == NodeType.DEPOT


# ---------------------------------------------------------------------------
# Route evaluation
# ---------------------------------------------------------------------------


def _make_instance_small():
    """3×3 grid: depot at (0,0), one customer at (3,4), one station at (6,0)."""
    from evrp.models import Depot, Customer, ChargingStation
    depot = Depot(node_id=0, x=0.0, y=0.0)
    customer = Customer(node_id=1, x=3.0, y=4.0, demand=20.0)
    station = ChargingStation(node_id=2, x=6.0, y=0.0)
    vehicle = Vehicle(
        vehicle_id=0, max_load=100.0, battery_capacity=60.0, consumption_rate=1.0
    )
    return EVRPInstance(
        name="tiny",
        depot=depot,
        customers=[customer],
        charging_stations=[station],
        vehicles=[vehicle],
    )


def test_evaluate_route_feasible():
    inst = _make_instance_small()
    vehicle = inst.vehicles[0]
    route = Route(
        vehicle=vehicle,
        nodes=[inst.depot, inst.customers[0], inst.depot],
    )
    inst.evaluate_route(route)
    assert route.is_feasible is True
    # distance: depot->customer = 5, customer->depot = 5
    assert math.isclose(route.total_distance, 10.0)
    assert math.isclose(route.total_load, 20.0)


def test_evaluate_route_load_infeasible():
    inst = _make_instance_small()
    # Give the vehicle a tiny max_load
    v = Vehicle(vehicle_id=0, max_load=5.0, battery_capacity=60.0)
    route = Route(
        vehicle=v,
        nodes=[inst.depot, inst.customers[0], inst.depot],
    )
    inst.evaluate_route(route)
    assert route.is_feasible is False


def test_evaluate_route_battery_infeasible():
    inst = _make_instance_small()
    # Give the vehicle tiny battery – not enough to reach the customer (d=5)
    v = Vehicle(vehicle_id=0, max_load=100.0, battery_capacity=3.0)
    route = Route(
        vehicle=v,
        nodes=[inst.depot, inst.customers[0], inst.depot],
    )
    inst.evaluate_route(route)
    assert route.is_feasible is False


def test_evaluate_route_recharges_at_station():
    inst = _make_instance_small()
    # Battery is only 6: depot->customer(d=5) leaves 1, not enough to return (d=5)
    # But depot->station(d=6)=exactly 6, then full recharge, station->depot=6 OK
    v = Vehicle(vehicle_id=0, max_load=100.0, battery_capacity=6.0)
    # Route via station: depot -> station -> customer_depot (can't directly)
    # Simple test: depot -> station -> depot  (distance=6+6=12, battery OK)
    route = Route(
        vehicle=v,
        nodes=[inst.depot, inst.charging_stations[0], inst.depot],
    )
    inst.evaluate_route(route)
    assert route.is_feasible is True
