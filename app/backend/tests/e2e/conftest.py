import pytest

def pytest_addoption(parser):
    parser.addoption(
        "--env", action="store", default="local", help="Environment to run tests against: local or azure"
    )

@pytest.fixture(scope="session")
def base_url(request):
    env = request.config.getoption("--env")
    if env == "azure":
        return "https://sipsara-ml-backend-app.azurewebsites.net"
    else:
        return "http://localhost:8080"
