{ lib
, buildPythonPackage
, fetchFromGitHub
, setuptools
, pbr
, oslo-utils
, prettytable
}:

buildPythonPackage rec {
  pname = "futurist";
  version = "3.2.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "openstack";
    repo = "futurist";
    rev = version;
    hash = "sha256-IrISdaVykQsRnfPk9bu1FpYtbyvMxzWm39FLpQmrFAM=";
  };

  # pbr needs version information from git or env variable
  env.PBR_VERSION = version;

  build-system = [
    setuptools
    pbr
  ];

  dependencies = [
    oslo-utils
    prettytable
  ];

  doCheck = false;
  pythonImportsCheck = [ "futurist" ];

  meta = with lib; {
    description = "Useful additions to futures, from the future";
    homepage = "https://github.com/openstack/futurist";
    license = licenses.asl20;
  };
}
