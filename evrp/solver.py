"""
Greedy nearest-neighbour solver for the basic EVRP.

Algorithm outline
-----------------
1. While there are unvisited customers:
   a. Take the next available vehicle (full battery, zero load).
   b. Starting from the depot, repeatedly move to the nearest unvisited
      customer that is *reachable* given the current battery and load.
   c. Before moving to a customer, check whether the vehicle has enough
      battery to reach the customer **and then** reach *some* node (charging
      station or depot) from the customer.  If the direct move would strand
      the vehicle, attempt to insert the nearest reachable charging station
      on the way.
   d. When no more customers can be added (load or battery would be
      violated), return the vehicle to the depot.
2. Return the resulting Solution.

This greedy heuristic does not guarantee optimality but always produces a
feasible solution (when one exists) and is a good baseline.
"""

from __future__ import annotations

from typing import List, Optional, Set

from evrp.instance import EVRPInstance
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


class GreedySolver:
    """Nearest-neighbour greedy solver for the EVRP.

    Usage::

        solver = GreedySolver(instance)
        solution = solver.solve()
    """

    def __init__(self, instance: EVRPInstance) -> None:
        self.instance = instance

    # ------------------------------------------------------------------
    # Public interface
    # ------------------------------------------------------------------

    def solve(self) -> Solution:
        """Build and return a greedy solution for the instance."""
        inst = self.instance
        unvisited: Set[int] = {c.node_id for c in inst.customers}
        solution = Solution()

        vehicle_idx = 0

        while unvisited:
            if vehicle_idx >= len(inst.vehicles):
                # No more vehicles – solution is infeasible but we still
                # return what we have so the caller can inspect partial results.
                break

            vehicle = inst.vehicles[vehicle_idx]
            vehicle_idx += 1

            route = self._build_route(vehicle, unvisited)
            inst.evaluate_route(route)
            solution.routes.append(route)

        return solution

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _build_route(
        self, vehicle: Vehicle, unvisited: Set[int]
    ) -> Route:
        """Construct a single greedy route for *vehicle*, removing served
        customers from *unvisited*.
        """
        inst = self.instance
        current: Node = inst.depot
        battery = vehicle.battery_capacity
        load = 0.0
        nodes: List[Node] = [inst.depot]

        while True:
            best_customer = self._nearest_feasible_customer(
                current, battery, load, vehicle, unvisited
            )
            if best_customer is None:
                if unvisited:
                    # No customer is directly reachable; try visiting a charging
                    # station that, after a full recharge, enables more customers.
                    cs = self._find_enabling_charging_station(
                        current, battery, load, vehicle, unvisited
                    )
                    if cs is not None:
                        dist_cs = inst.distance(current, cs)
                        battery -= dist_cs * vehicle.consumption_rate
                        nodes.append(cs)
                        battery = vehicle.battery_capacity  # fully recharged
                        current = cs
                        continue  # Retry with fresh battery
                break  # No reachable customer – close the route

            # Possibly insert a charging station before the customer
            cs = self._nearest_charging_station_en_route(
                current, best_customer, battery, vehicle
            )
            if cs is not None:
                nodes.append(cs)
                battery = vehicle.battery_capacity  # fully recharged
                current = cs

            # Travel to the customer
            dist = inst.distance(current, best_customer)
            battery -= dist * vehicle.consumption_rate
            load += best_customer.demand
            nodes.append(best_customer)
            unvisited.discard(best_customer.node_id)
            current = best_customer

        # Return to depot (possibly via a charging station if needed)
        dist_home = inst.distance(current, inst.depot)
        energy_home = dist_home * vehicle.consumption_rate
        if battery < energy_home - 1e-9:
            # Need a charging stop before returning
            cs = self._find_reachable_charging_station(current, battery, vehicle)
            if cs is not None:
                nodes.append(cs)
                battery = vehicle.battery_capacity
                current = cs

        nodes.append(inst.depot)
        return Route(vehicle=vehicle, nodes=nodes)

    def _nearest_feasible_customer(
        self,
        current: Node,
        battery: float,
        load: float,
        vehicle: Vehicle,
        unvisited: Set[int],
    ) -> Optional[Customer]:
        """Return the nearest unvisited customer that is reachable.

        A customer is reachable if:
        1. Adding its demand would not exceed vehicle.max_load.
        2. The remaining battery is sufficient to reach the customer **and**
           then reach either the depot or a charging station from the
           customer (so the vehicle is never stranded).
        """
        inst = self.instance
        best: Optional[Customer] = None
        best_dist = float("inf")

        for cid in unvisited:
            customer: Customer = inst.node_by_id(cid)  # type: ignore[assignment]

            # Load check
            if load + customer.demand > vehicle.max_load + 1e-9:
                continue

            # Battery: can we reach the customer?
            d_to_customer = inst.distance(current, customer)
            energy_to_customer = d_to_customer * vehicle.consumption_rate
            if battery - energy_to_customer < -1e-9:
                continue

            # Battery: can we then reach *somewhere safe* (depot or station)?
            battery_at_customer = battery - energy_to_customer
            if not self._can_escape(customer, battery_at_customer, vehicle):
                continue

            if d_to_customer < best_dist:
                best_dist = d_to_customer
                best = customer

        return best

    def _can_escape(
        self, node: Node, battery: float, vehicle: Vehicle
    ) -> bool:
        """Return True if the vehicle can reach the depot or a charging station
        from *node* with the given *battery* level.
        """
        inst = self.instance
        candidates: List[Node] = [inst.depot] + list(inst.charging_stations)
        for target in candidates:
            d = inst.distance(node, target)
            if battery - d * vehicle.consumption_rate >= -1e-9:
                return True
        return False

    def _nearest_charging_station_en_route(
        self,
        current: Node,
        destination: Customer,
        battery: float,
        vehicle: Vehicle,
    ) -> Optional[ChargingStation]:
        """If the vehicle cannot reach *destination* directly, return the
        nearest reachable charging station.  Otherwise return None.
        """
        inst = self.instance
        d_direct = inst.distance(current, destination)
        if battery - d_direct * vehicle.consumption_rate >= -1e-9:
            return None  # Direct travel is fine

        return self._find_reachable_charging_station(current, battery, vehicle)

    def _find_enabling_charging_station(
        self,
        current: Node,
        battery: float,
        load: float,
        vehicle: Vehicle,
        unvisited: Set[int],
    ) -> Optional[ChargingStation]:
        """Return the nearest reachable charging station from which at least
        one unvisited customer becomes feasible after a full recharge.
        """
        inst = self.instance
        best: Optional[ChargingStation] = None
        best_dist = float("inf")

        for cs in inst.charging_stations:
            d_to_cs = inst.distance(current, cs)
            # Can we reach this charging station?
            if battery - d_to_cs * vehicle.consumption_rate < -1e-9:
                continue
            # After full recharge at this station, can we reach any customer?
            if self._nearest_feasible_customer(
                cs, vehicle.battery_capacity, load, vehicle, unvisited
            ) is not None:
                if d_to_cs < best_dist:
                    best_dist = d_to_cs
                    best = cs

        return best

    def _find_reachable_charging_station(
        self, current: Node, battery: float, vehicle: Vehicle
    ) -> Optional[ChargingStation]:
        """Return the nearest charging station reachable from *current* given
        *battery*.
        """
        inst = self.instance
        best: Optional[ChargingStation] = None
        best_dist = float("inf")

        for cs in inst.charging_stations:
            d = inst.distance(current, cs)
            if battery - d * vehicle.consumption_rate >= -1e-9:
                if d < best_dist:
                    best_dist = d
                    best = cs

        return best
