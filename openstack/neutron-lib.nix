{ lib
, buildPythonPackage
, fetchFromGitHub
, setuptools
, pbr
, keystoneauth1
, netaddr
, os-ken
, oslo-concurrency
, oslo-config
, oslo-context
, oslo-db
, oslo-i18n
, oslo-log
, oslo-messaging
, oslo-policy
, oslo-serialization
, oslo-utils
, oslo-versionedobjects
, os-traits
, osprofiler
, pecan
, setproctitle
, sqlalchemy
, stevedore
, webob
, oslo-service
}:

buildPythonPackage rec {
  pname = "neutron-lib";
  version = "3.22.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "openstack";
    repo = "neutron-lib";
    rev = version;
    hash = "sha256-kGCR9zqYFb/KCALSk2QXv9NTesp9+0FULHw8Z9BYujE=";
  };

  # pbr needs version information from git or env variable
  env.PBR_VERSION = version;

  build-system = [
    setuptools
    pbr
  ];

  dependencies = [
    keystoneauth1
    netaddr
    os-ken
    oslo-concurrency
    oslo-config
    oslo-context
    oslo-db
    oslo-i18n
    oslo-log
    oslo-messaging
    oslo-policy
    oslo-serialization
    oslo-utils
    oslo-versionedobjects
    os-traits
    osprofiler
    pecan
    setproctitle
    sqlalchemy
    stevedore
    webob
    oslo-service
  ];

  doCheck = false;
  pythonImportsCheck = [ "neutron_lib" ];

  meta = with lib; {
    description = "Neutron shared routines and utilities";
    homepage = "https://github.com/openstack/neutron-lib";
    license = licenses.asl20;
  };
}
