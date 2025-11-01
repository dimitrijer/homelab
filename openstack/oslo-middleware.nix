{ lib
, buildPythonPackage
, fetchFromGitHub
, setuptools
, pbr
, bcrypt
, debtcollector
, jinja2
, oslo-config
, oslo-context
, oslo-i18n
, oslo-utils
, oslo-serialization
, statsd
, stevedore
, webob
, stestr
, oslotest
, testtools
, fixtures
}:

buildPythonPackage rec {
  pname = "oslo.middleware";
  version = "6.6.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "openstack";
    repo = "oslo.middleware";
    rev = version;
    hash = "sha256-JisfUcGs3Xd/pZuXXhdlITlGfBjvLPXYCQ74YSJGt38=";
  };

  # pbr needs version information from git or env variable
  env.PBR_VERSION = version;

  build-system = [
    setuptools
    pbr
  ];

  dependencies = [
    bcrypt
    debtcollector
    jinja2
    oslo-config
    oslo-context
    oslo-i18n
    oslo-utils
    oslo-serialization
    statsd
    stevedore
    webob
  ];

  nativeCheckInputs = [
    stestr
    oslotest
    testtools
    fixtures
  ];

  checkPhase = ''
    runHook preCheck
    stestr run
    runHook postCheck
  '';

  pythonImportsCheck = [ "oslo_middleware" ];

  meta = with lib; {
    description = "Oslo Middleware library";
    homepage = "https://github.com/openstack/oslo.middleware";
    license = licenses.asl20;
  };
}
