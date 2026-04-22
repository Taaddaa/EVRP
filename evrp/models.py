"""
Data models for the Electric Vehicle Routing Problem (EVRP).

Node types:
    - Depot: starting and ending point for all routes
    - Customer: node with a demand that must be served
    - ChargingStation: node where a vehicle can recharge its battery

A Vehicle is an electric vehicle characterised by its cargo capacity (max_load)
and its battery capacity (battery_capacity).  Energy is consumed at a constant
rate (consumption_rate) per unit of distance travelled.

A Route is an ordered sequence of nodes visited by a single vehicle starting
and ending at the depot.

A Solution is a collection of Routes that together serve every customer exactly
once.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from typing import List


class NodeType(Enum):
    DEPOT = "depot"
    CUSTOMER = "customer"
    CHARGING_STATION = "charging_station"


@dataclass
class Node:
    """A location in the EVRP network."""

    node_id: int
    x: float
    y: float
    node_type: NodeType

    def __repr__(self) -> str:
        return f"Node({self.node_id}, type={self.node_type.value}, x={self.x}, y={self.y})"


@dataclass
class Depot(Node):
    """The depot – vehicles start and end their routes here."""

    def __init__(self, node_id: int, x: float, y: float) -> None:
        super().__init__(node_id=node_id, x=x, y=y, node_type=NodeType.DEPOT)


@dataclass
class Customer(Node):
    """A customer node with a service demand."""

    demand: float = 0.0

    def __init__(self, node_id: int, x: float, y: float, demand: float = 0.0) -> None:
        super().__init__(node_id=node_id, x=x, y=y, node_type=NodeType.CUSTOMER)
        self.demand = demand


@dataclass
class ChargingStation(Node):
    """A charging station where a vehicle can recharge its battery to full."""

    def __init__(self, node_id: int, x: float, y: float) -> None:
        super().__init__(
            node_id=node_id, x=x, y=y, node_type=NodeType.CHARGING_STATION
        )


@dataclass
class Vehicle:
    """An electric vehicle used to serve customers.

    Attributes:
        vehicle_id: unique identifier.
        max_load: maximum cargo (demand) the vehicle can carry.
        battery_capacity: maximum battery level (energy units).
        consumption_rate: energy consumed per unit of distance.
    """

    vehicle_id: int
    max_load: float
    battery_capacity: float
    consumption_rate: float = 1.0

    @property
    def initial_battery(self) -> float:
        """Vehicles depart the depot with a full battery."""
        return self.battery_capacity


@dataclass
class Route:
    """An ordered sequence of nodes visited by one vehicle.

    The route implicitly starts and ends at the depot; the depot node itself
    should appear as the first and last element of ``nodes``.
    """

    vehicle: Vehicle
    nodes: List[Node] = field(default_factory=list)

    # Computed metrics (populated by EVRPInstance.evaluate_route)
    total_distance: float = 0.0
    total_load: float = 0.0
    is_feasible: bool = True

    def __repr__(self) -> str:
        ids = " -> ".join(str(n.node_id) for n in self.nodes)
        return (
            f"Route(vehicle={self.vehicle.vehicle_id}, "
            f"distance={self.total_distance:.2f}, "
            f"feasible={self.is_feasible}, "
            f"path=[{ids}])"
        )


@dataclass
class Solution:
    """A complete EVRP solution: a set of routes that serve all customers.

    Attributes:
        routes: list of Route objects, one per vehicle used.
        total_distance: sum of distances across all routes.
        is_feasible: True if every route is feasible.
    """

    routes: List[Route] = field(default_factory=list)

    @property
    def total_distance(self) -> float:
        return sum(r.total_distance for r in self.routes)

    @property
    def is_feasible(self) -> bool:
        return all(r.is_feasible for r in self.routes)

    def __repr__(self) -> str:
        return (
            f"Solution(routes={len(self.routes)}, "
            f"total_distance={self.total_distance:.2f}, "
            f"feasible={self.is_feasible})"
        )
