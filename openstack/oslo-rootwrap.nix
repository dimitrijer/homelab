{ lib
, buildPythonPackage
, fetchFromGitHub
, setuptools
, pbr
, debtcollector
}:

buildPythonPackage rec {
  pname = "oslo.rootwrap";
  version = "7.7.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "openstack";
    repo = "oslo.rootwrap";
    rev = version;
    hash = "sha256-XGnecoVlxkPxWhMleervloHso4G4ljBfP+rCtI2Toms=";
  };

  # pbr needs version information from git or env variable
  env.PBR_VERSION = version;

  build-system = [
    setuptools
    pbr
  ];

  dependencies = [
    debtcollector
  ];

  doCheck = false;
  pythonImportsCheck = [ "oslo_rootwrap" ];

  meta = with lib; {
    description = "Oslo Rootwrap allows fine-grained filtering of shell commands to run as root";
    homepage = "https://github.com/openstack/oslo.rootwrap";
    license = licenses.asl20;
  };
}
