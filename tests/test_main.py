import pytest
from fastapi.testclient import TestClient
from unittest.mock import Mock, patch
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))
from main import app


@pytest.fixture
def client():
    return TestClient(app)


@pytest.fixture
def mock_docker_client():
    with patch('main.docker_client') as mock_client:
        mock_client.ping.return_value = True
        yield mock_client


def test_root_endpoint(client):
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["service"] == "Container Resource Monitor"
    assert "endpoints" in data


def test_health_endpoint_with_docker(client, mock_docker_client):
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert data["docker_connected"] is True


def test_health_endpoint_without_docker(client):
    with patch('main.docker_client', None):
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "degraded"
        assert data["docker_connected"] is False


def test_metrics_endpoint(client, mock_docker_client):
    mock_container = Mock()
    mock_container.id = "abc123"
    mock_container.name = "test"
    mock_container.status = "running"
    mock_container.stats.return_value = {
        "cpu_stats": {"cpu_usage": {"total_usage": 200000000, "percpu_usage": [1, 1]}, "system_cpu_usage": 400000000},
        "precpu_stats": {"cpu_usage": {"total_usage": 100000000}, "system_cpu_usage": 200000000},
        "memory_stats": {"usage": 104857600, "limit": 1073741824},
        "networks": {"eth0": {"rx_bytes": 1048576, "tx_bytes": 2097152}},
        "blkio_stats": {"io_service_bytes_recursive": [{"op": "Read", "value": 5242880}]}
    }

    mock_docker_client.containers.list.return_value = [mock_container]

    response = client.get("/metrics")
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["container_name"] == "test"
