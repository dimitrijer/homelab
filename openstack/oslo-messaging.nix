{ lib
, buildPythonPackage
, fetchFromGitHub
, setuptools
, pbr
, amqp
, cachetools
, kombu
, oslo-config
, oslo-i18n
, oslo-log
, oslo-metrics
, oslo-serialization
, oslo-utils
, pyyaml
, stevedore
, webob
, futurist
, oslo-middleware
, oslo-service
}:

buildPythonPackage rec {
  pname = "oslo.messaging";
  version = "17.1.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "openstack";
    repo = "oslo.messaging";
    rev = version;
    hash = "sha256-E3Gz/kpyC0vyV0897KlZ4jawqBqc/I+YTPMwRYloZCM=";
  };

  # pbr needs version information from git or env variable
  env.PBR_VERSION = version;

  build-system = [
    setuptools
    pbr
  ];

  dependencies = [
    amqp
    cachetools
    kombu
    oslo-config
    oslo-i18n
    oslo-log
    oslo-metrics
    oslo-serialization
    oslo-utils
    pyyaml
    stevedore
    webob
    futurist
    oslo-middleware
    oslo-service
  ];

  doCheck = false;
  pythonImportsCheck = [ "oslo_messaging" ];

  meta = with lib; {
    description = "Oslo Messaging library";
    homepage = "https://github.com/openstack/oslo.messaging";
    license = licenses.asl20;
  };
}
