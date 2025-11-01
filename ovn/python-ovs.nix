{ lib
, buildPythonPackage
, fetchPypi
, setuptools
, sortedcontainers
}:

buildPythonPackage rec {
  pname = "ovs";
  version = "3.4.0";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-5RpdyeApbwM3RplKi81LVfqJohYNzcCHrGTjDLfJwNc=";
  };

  build-system = [
    setuptools
  ];

  dependencies = [
    sortedcontainers
  ];

  doCheck = false;
  pythonImportsCheck = [ "ovs" ];

  meta = with lib; {
    description = "Python bindings for Open vSwitch";
    homepage = "https://pypi.org/project/ovs/";
    license = licenses.asl20;
  };
}
