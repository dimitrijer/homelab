{ lib
, buildPythonPackage
, fetchFromGitHub
, setuptools
, pbr
, oslo-config
, oslo-log
, oslo-utils
, cffi
, eventlet
, greenlet
, msgpack
}:

buildPythonPackage rec {
  pname = "oslo.privsep";
  version = "3.8.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "openstack";
    repo = "oslo.privsep";
    rev = version;
    hash = "sha256-BBp5GTPp5LttjQbzjAFfUPGGp+9V5PIPW9ZbnVE8jww=";
  };

  # pbr needs version information from git or env variable
  env.PBR_VERSION = version;

  build-system = [
    setuptools
    pbr
  ];

  dependencies = [
    oslo-config
    oslo-log
    oslo-utils
    cffi
    eventlet
    greenlet
    msgpack
  ];

  doCheck = false;
  pythonImportsCheck = [ "oslo_privsep" ];

  meta = with lib; {
    description = "OpenStack library for privilege separation";
    homepage = "https://github.com/openstack/oslo.privsep";
    license = licenses.asl20;
  };
}
