"""
EVRPInstance – the central data object for an EVRP problem.

File format (plain-text, whitespace-separated columns)
-------------------------------------------------------
Line 1:   ``# EVRP instance: <name>``  (comment, ignored)
Line 2:   ``n_customers <int>``
Line 3:   ``n_stations  <int>``
Line 4:   ``n_vehicles  <int>``
Line 5:   ``max_load    <float>``
Line 6:   ``battery_capacity <float>``
Line 7:   ``consumption_rate <float>``
Line 8+:  one node per line with columns:
          ``<id> <type> <x> <y> [demand]``
          where type is one of: depot | customer | charging_station

Example
-------
::

    # EVRP instance: sample
    n_customers 5
    n_stations  2
    n_vehicles  3
    max_load    100
    battery_capacity 60
    consumption_rate 1
    0 depot           0   0
    1 customer       10  20  20
    2 customer       30  10  30
    3 customer       20  40  15
    4 customer       50  30  25
    5 customer       40  50  10
    6 charging_station 15  35
    7 charging_station 45  15
"""

from __future__ import annotations

import os
from typing import Dict, List, Optional

from evrp.distance import build_distance_matrix, euclidean_distance
from evrp.models import (
    ChargingStation,
    Customer,
    Depot,
    Node,
    NodeType,
    Route,
    Vehicle,
)


class EVRPInstance:
    """Holds all data for one EVRP problem instance.

    Attributes:
        name: instance name.
        depot: the depot node.
        customers: list of customer nodes.
        charging_stations: list of charging station nodes.
        vehicles: list of available vehicles.
        nodes: all nodes (depot first, then customers, then stations) – index
               matches the distance matrix.
        distance_matrix: ``distance_matrix[i][j]`` is the distance from
                         ``nodes[i]`` to ``nodes[j]``.
    """

    def __init__(
        self,
        name: str,
        depot: Depot,
        customers: List[Customer],
        charging_stations: List[ChargingStation],
        vehicles: List[Vehicle],
    ) -> None:
        self.name = name
        self.depot = depot
        self.customers = customers
        self.charging_stations = charging_stations
        self.vehicles = vehicles

        # Build a unified, ordered list of all nodes.
        self.nodes: List[Node] = (
            [depot] + list(customers) + list(charging_stations)
        )

        # Map node_id -> index in self.nodes for O(1) look-ups.
        self._id_to_index: Dict[int, int] = {
            node.node_id: idx for idx, node in enumerate(self.nodes)
        }

        self.distance_matrix: List[List[float]] = build_distance_matrix(
            self.nodes
        )

    # ------------------------------------------------------------------
    # Convenience helpers
    # ------------------------------------------------------------------

    def distance(self, a: Node, b: Node) -> float:
        """Return the distance between two nodes (uses the precomputed matrix)."""
        i = self._id_to_index[a.node_id]
        j = self._id_to_index[b.node_id]
        return self.distance_matrix[i][j]

    def node_by_id(self, node_id: int) -> Node:
        """Return the node with the given id."""
        idx = self._id_to_index[node_id]
        return self.nodes[idx]

    # ------------------------------------------------------------------
    # Route evaluation
    # ------------------------------------------------------------------

    def evaluate_route(self, route: Route) -> Route:
        """Compute distance, load, and feasibility of a route in-place.

        A route is feasible when:
        - The total load never exceeds ``vehicle.max_load``.
        - The battery level never falls below zero.
        - The route starts and ends at the depot.

        Charging stations fully recharge the battery to ``battery_capacity``.

        Args:
            route: the Route to evaluate.  ``route.nodes`` must begin and end
                   with the depot.

        Returns:
            The same ``route`` object with updated metrics.
        """
        vehicle = route.vehicle
        nodes = route.nodes

        total_dist = 0.0
        current_load = 0.0
        current_battery = vehicle.battery_capacity
        feasible = True

        if not nodes:
            route.total_distance = 0.0
            route.total_load = 0.0
            route.is_feasible = True
            return route

        for i in range(len(nodes) - 1):
            from_node = nodes[i]
            to_node = nodes[i + 1]
            d = self.distance(from_node, to_node)
            total_dist += d
            energy_needed = d * vehicle.consumption_rate
            current_battery -= energy_needed
            if current_battery < -1e-9:
                feasible = False
                current_battery = 0.0  # clamp to avoid cascading negatives

            # Process arriving at to_node
            if to_node.node_type == NodeType.CUSTOMER:
                current_load += to_node.demand  # type: ignore[attr-defined]
                if current_load > vehicle.max_load + 1e-9:
                    feasible = False
            elif to_node.node_type == NodeType.CHARGING_STATION:
                current_battery = vehicle.battery_capacity

        route.total_distance = total_dist
        route.total_load = current_load
        route.is_feasible = feasible
        return route

    # ------------------------------------------------------------------
    # I/O
    # ------------------------------------------------------------------

    @classmethod
    def from_file(cls, filepath: str) -> "EVRPInstance":
        """Load an EVRPInstance from a plain-text file.

        See the module docstring for the expected file format.

        Args:
            filepath: path to the instance file.

        Returns:
            A fully constructed EVRPInstance.

        Raises:
            FileNotFoundError: if the file does not exist.
            ValueError: if the file is malformed.
        """
        if not os.path.isfile(filepath):
            raise FileNotFoundError(f"Instance file not found: {filepath}")

        params: Dict[str, str] = {}
        node_lines: List[str] = []

        with open(filepath, "r", encoding="utf-8") as fh:
            for raw_line in fh:
                line = raw_line.strip()
                if not line or line.startswith("#"):
                    continue
                parts = line.split()
                if parts[0] in (
                    "n_customers",
                    "n_stations",
                    "n_vehicles",
                    "max_load",
                    "battery_capacity",
                    "consumption_rate",
                ):
                    params[parts[0]] = parts[1]
                else:
                    node_lines.append(line)

        name = os.path.splitext(os.path.basename(filepath))[0]

        try:
            n_vehicles = int(params["n_vehicles"])
            max_load = float(params["max_load"])
            battery_capacity = float(params["battery_capacity"])
            consumption_rate = float(params["consumption_rate"])
        except KeyError as exc:
            raise ValueError(
                f"Missing required parameter in instance file: {exc}"
            ) from exc

        depot: Optional[Depot] = None
        customers: List[Customer] = []
        charging_stations: List[ChargingStation] = []

        for raw in node_lines:
            parts = raw.split()
            if len(parts) < 4:
                raise ValueError(f"Malformed node line: {raw!r}")
            node_id = int(parts[0])
            node_type_str = parts[1].lower()
            x = float(parts[2])
            y = float(parts[3])

            if node_type_str == "depot":
                depot = Depot(node_id=node_id, x=x, y=y)
            elif node_type_str == "customer":
                demand = float(parts[4]) if len(parts) > 4 else 0.0
                customers.append(
                    Customer(node_id=node_id, x=x, y=y, demand=demand)
                )
            elif node_type_str == "charging_station":
                charging_stations.append(
                    ChargingStation(node_id=node_id, x=x, y=y)
                )
            else:
                raise ValueError(f"Unknown node type: {node_type_str!r}")

        if depot is None:
            raise ValueError("Instance file must contain exactly one depot node.")

        vehicles = [
            Vehicle(
                vehicle_id=i,
                max_load=max_load,
                battery_capacity=battery_capacity,
                consumption_rate=consumption_rate,
            )
            for i in range(n_vehicles)
        ]

        return cls(
            name=name,
            depot=depot,
            customers=customers,
            charging_stations=charging_stations,
            vehicles=vehicles,
        )

    def __repr__(self) -> str:
        return (
            f"EVRPInstance(name={self.name!r}, "
            f"customers={len(self.customers)}, "
            f"stations={len(self.charging_stations)}, "
            f"vehicles={len(self.vehicles)})"
        )
