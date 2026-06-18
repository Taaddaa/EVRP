"""Tests for evrp.distance."""

import math
import pytest
from evrp.models import Customer, Depot
from evrp.distance import euclidean_distance, build_distance_matrix


def test_euclidean_distance_zero():
    a = Depot(node_id=0, x=0.0, y=0.0)
    assert euclidean_distance(a, a) == 0.0


def test_euclidean_distance_3_4_5():
    a = Depot(node_id=0, x=0.0, y=0.0)
    b = Customer(node_id=1, x=3.0, y=4.0, demand=0.0)
    assert math.isclose(euclidean_distance(a, b), 5.0)


def test_euclidean_distance_symmetric():
    a = Depot(node_id=0, x=1.0, y=2.0)
    b = Customer(node_id=1, x=4.0, y=6.0, demand=0.0)
    assert math.isclose(euclidean_distance(a, b), euclidean_distance(b, a))


def test_build_distance_matrix_diagonal_zero():
    nodes = [
        Depot(node_id=0, x=0.0, y=0.0),
        Customer(node_id=1, x=3.0, y=4.0, demand=10.0),
    ]
    matrix = build_distance_matrix(nodes)
    assert matrix[0][0] == 0.0
    assert matrix[1][1] == 0.0


def test_build_distance_matrix_values():
    nodes = [
        Depot(node_id=0, x=0.0, y=0.0),
        Customer(node_id=1, x=3.0, y=4.0, demand=10.0),
    ]
    matrix = build_distance_matrix(nodes)
    assert math.isclose(matrix[0][1], 5.0)
    assert math.isclose(matrix[1][0], 5.0)


def test_build_distance_matrix_symmetric():
    nodes = [
        Depot(node_id=0, x=0.0, y=0.0),
        Customer(node_id=1, x=3.0, y=4.0, demand=10.0),
        Customer(node_id=2, x=6.0, y=0.0, demand=5.0),
    ]
    matrix = build_distance_matrix(nodes)
    for i in range(len(nodes)):
        for j in range(len(nodes)):
            assert math.isclose(matrix[i][j], matrix[j][i])
