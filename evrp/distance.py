"""
Distance utilities for the EVRP.

All distance calculations are based on the 2-D Euclidean metric, which is the
standard used in the EVRP benchmark literature.
"""

from __future__ import annotations

import math
from typing import List

from evrp.models import Node


def euclidean_distance(a: Node, b: Node) -> float:
    """Return the Euclidean distance between two nodes."""
    return math.sqrt((a.x - b.x) ** 2 + (a.y - b.y) ** 2)


def build_distance_matrix(nodes: List[Node]) -> List[List[float]]:
    """Build a full pairwise distance matrix for a list of nodes.

    Returns a 2-D list ``matrix`` where ``matrix[i][j]`` is the distance
    from ``nodes[i]`` to ``nodes[j]``.  The matrix is symmetric and the
    diagonal is zero.
    """
    n = len(nodes)
    matrix: List[List[float]] = [[0.0] * n for _ in range(n)]
    for i in range(n):
        for j in range(i + 1, n):
            d = euclidean_distance(nodes[i], nodes[j])
            matrix[i][j] = d
            matrix[j][i] = d
    return matrix
