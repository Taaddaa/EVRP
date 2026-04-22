"""
evrp – Electric Vehicle Routing Problem package.

Quick-start example::

    from evrp.instance import EVRPInstance
    from evrp.solver import GreedySolver

    instance = EVRPInstance.from_file("data/sample.evrp")
    solver = GreedySolver(instance)
    solution = solver.solve()
    print(solution)
    for route in solution.routes:
        print(route)
"""

from evrp.models import (  # noqa: F401
    ChargingStation,
    Customer,
    Depot,
    Node,
    NodeType,
    Route,
    Solution,
    Vehicle,
)
from evrp.instance import EVRPInstance  # noqa: F401
from evrp.solver import GreedySolver  # noqa: F401

__version__ = "0.1.0"
__all__ = [
    "ChargingStation",
    "Customer",
    "Depot",
    "EVRPInstance",
    "GreedySolver",
    "Node",
    "NodeType",
    "Route",
    "Solution",
    "Vehicle",
]
