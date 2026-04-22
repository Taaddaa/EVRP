#!/usr/bin/env python3
"""
main.py – command-line entry point for the EVRP greedy solver.

Usage
-----
    python main.py data/sample.evrp

The script loads the instance, runs the GreedySolver, prints the solution
summary, and then prints each route.
"""

from __future__ import annotations

import sys

from evrp.instance import EVRPInstance
from evrp.solver import GreedySolver


def main(filepath: str) -> None:
    print(f"Loading instance from: {filepath}")
    instance = EVRPInstance.from_file(filepath)
    print(instance)
    print()

    solver = GreedySolver(instance)
    solution = solver.solve()

    print(solution)
    print()

    for i, route in enumerate(solution.routes, start=1):
        print(f"  Route {i}: {route}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python main.py <instance_file>")
        sys.exit(1)
    main(sys.argv[1])
