{ lib, python3, fetchFromGitHub }:

python3.pkgs.buildPythonApplication {
  pname = "prometheus-ganeti-exporter";
  version = "1.1.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "ganeti";
    repo = "prometheus-ganeti-exporter";
    rev = "4dbcc386c835d17db619ff427107d4c304ed04dc";
    hash = "sha256-6kfqom+sSh+SgljNHbBbJ0LLQXPWeYkTXImyYtys5D0=";
  };

  build-system = with python3.pkgs; [ setuptools ];

  dependencies = with python3.pkgs; [
    prometheus-client
    requests
    urllib3
  ];

  nativeCheckInputs = with python3.pkgs; [
    pytestCheckHook
    pytest-mock
  ];

  meta = with lib; {
    description = "Prometheus exporter for Ganeti metrics";
    license = licenses.bsd2;
    mainProgram = "prometheus-ganeti-exporter";
  };
}
