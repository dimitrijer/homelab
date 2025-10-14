{ lib
, buildPythonPackage
, fetchFromGitHub
, setuptools
, pbr
, eventlet
, msgpack
, ncclient
, netaddr
, ovs
, oslo-config
, routes
, webob
}:

buildPythonPackage rec {
  pname = "os-ken";
  version = "3.1.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "openstack";
    repo = "os-ken";
    rev = version;
    hash = "sha256-qb+OSgKeSa6hzbK/snOkBHLX4Zdc9Yu9e8tVEsDUNSE=";
  };

  # pbr needs version information from git or env variable
  env.PBR_VERSION = version;

  build-system = [
    setuptools
    pbr
  ];

  dependencies = [
    eventlet
    msgpack
    ncclient
    netaddr
    ovs
    oslo-config
    routes
    webob
  ];

  doCheck = false;
  pythonImportsCheck = [ "os_ken" ];

  meta = with lib; {
    description = "OpenStack os-ken library - component-based software defined networking framework";
    homepage = "https://github.com/openstack/os-ken";
    license = licenses.asl20;
  };
}
