{ lib
, buildPythonPackage
, fetchFromGitHub
, setuptools
, pbr
, oslo-utils
, prettytable
, stestr
, oslotest
, testtools
, testscenarios
, eventlet
, oslo-log
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

  nativeCheckInputs = [
    stestr
    oslotest
    testtools
    testscenarios
    eventlet
    oslo-log
  ];

  # Python 3.14 changed the default multiprocessing start method to
  # "forkserver". Under stestr's process model, a forked child process runs the
  # inherited _remove_temp_dir finalizer and deletes the parent's pymp-* temp
  # directory, which also holds the forkserver's control socket. The next
  # connect_to_new_process then fails with ENOENT, and every (process) scenario
  # test fails with "FileNotFoundError". Forcing the "fork" start method avoids
  # the forkserver socket entirely and the whole suite passes.
  preCheck = ''
    mkdir -p $TMPDIR/sitecustomize
    cat > $TMPDIR/sitecustomize/sitecustomize.py << 'PYEOF'
import multiprocessing as mp
try:
    mp.set_start_method("fork")
except RuntimeError:
    pass
PYEOF
    export PYTHONPATH="$TMPDIR/sitecustomize''${PYTHONPATH:+:$PYTHONPATH}"
  '';

  checkPhase = ''
    runHook preCheck
    stestr run
    runHook postCheck
  '';

  pythonImportsCheck = [ "futurist" ];

  meta = with lib; {
    description = "Useful additions to futures, from the future";
    homepage = "https://github.com/openstack/futurist";
    license = licenses.asl20;
  };
}
