{ lib
, buildPythonPackage
, fetchPypi
, python3
}:

let
  # OVS Python bindings
  ovs = buildPythonPackage rec {
    pname = "ovs";
    version = "3.4.0";
    pyproject = true;

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-5RpdyeApbwM3RplKi81LVfqJohYNzcCHrGTjDLfJwNc=";
    };

    build-system = with python3.pkgs; [
      setuptools
    ];

    dependencies = with python3.pkgs; [
      sortedcontainers
    ];

    doCheck = false;
    pythonImportsCheck = [ "ovs" ];
  };

  # Oslo packages that are missing from nixpkgs
  oslo-privsep = buildPythonPackage rec {
    pname = "oslo.privsep";
    version = "3.3.0";
    pyproject = true;

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-WzkAJJ4So3N95tqiDS+HK8L0wbch0qscyiI30sKVnOs=";
    };

    build-system = with python3.pkgs; [
      setuptools
      pbr
    ];

    dependencies = with python3.pkgs; [
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
  };

  futurist = buildPythonPackage rec {
    pname = "futurist";
    version = "3.0.0";
    pyproject = true;

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-ZCIBF5JBTDkijhFL7FSUMDqvBtzTNeT43U+Qf3ikH3k=";
    };

    build-system = with python3.pkgs; [
      setuptools
      pbr
    ];

    dependencies = with python3.pkgs; [
      oslo-utils
      prettytable
    ];

    doCheck = false;
    pythonImportsCheck = [ "futurist" ];
  };

  oslo-middleware = buildPythonPackage rec {
    pname = "oslo.middleware";
    version = "6.2.0";
    pyproject = true;

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-mZWavluqbWNycw0eZ6V7Qp+3fHN+HAPciwAMyvI5TNQ=";
    };

    build-system = with python3.pkgs; [
      setuptools
      pbr
    ];

    dependencies = with python3.pkgs; [
      bcrypt
      debtcollector
      jinja2
      oslo-config
      oslo-context
      oslo-i18n
      oslo-utils
      statsd
      stevedore
      webob
    ];

    doCheck = false;
    pythonImportsCheck = [ "oslo_middleware" ];
  };

  oslo-messaging = buildPythonPackage rec {
    pname = "oslo.messaging";
    version = "14.8.1";
    pyproject = true;

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-GuNfcfj7K72Fm9ucRvRGikUSeNFeTIjBFLT74Qt9h/Q=";
    };

    build-system = with python3.pkgs; [
      setuptools
      pbr
    ];

    dependencies = with python3.pkgs; [
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
    ] ++ [
      futurist
      oslo-middleware
      oslo-service
    ];

    doCheck = false;
    pythonImportsCheck = [ "oslo_messaging" ];
  };

  oslo-service = buildPythonPackage rec {
    pname = "oslo.service";
    version = "3.4.0";
    pyproject = true;

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-slNMpqk3OTb76B3nhh4yoMP4W+gKnEdTVMIfyW5SpCc=";
    };

    build-system = with python3.pkgs; [
      setuptools
      pbr
    ];

    dependencies = with python3.pkgs; [
      eventlet
      oslo-concurrency
      oslo-config
      oslo-i18n
      oslo-log
      oslo-utils
      paste
      pastedeploy
      routes
      webob
      yappi
    ] ++ [
      oslo-privsep
    ];

    doCheck = false;
    pythonImportsCheck = [ "oslo_service" ];
  };

  neutron-lib = buildPythonPackage rec {
    pname = "neutron-lib";
    version = "3.8.0";
    pyproject = true;

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-EfVqLhFEBaE7OfsRHdwYFiiQNWbXmOsonvEL83U3e3c=";
    };

    build-system = with python3.pkgs; [
      setuptools
      pbr
    ];

    dependencies = with python3.pkgs; [
      netaddr
      oslo-concurrency
      oslo-config
      oslo-context
      oslo-db
      oslo-i18n
      oslo-log
      oslo-messaging
      oslo-serialization
      oslo-utils
      osprofiler
      pecan
      sqlalchemy
      stevedore
      webob
    ] ++ [
      oslo-service
    ];

    doCheck = false;
    pythonImportsCheck = [ "neutron_lib" ];
  };

  ovsdbapp = buildPythonPackage rec {
    pname = "ovsdbapp";
    version = "2.7.0";
    pyproject = true;

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-oDpXV916XKxMuMmT5o6lYFx3/8QyYLf5W0zJ9QGtRTA=";
    };

    build-system = with python3.pkgs; [
      setuptools
      pbr
    ];

    dependencies = with python3.pkgs; [
      fixtures
      netaddr
      oslo-log
      oslo-serialization
      oslo-utils
    ] ++ [
      ovs
    ];

    doCheck = false;
    pythonImportsCheck = [ "ovsdbapp" ];
  };

in
{
  inherit
    ovs
    futurist
    oslo-privsep
    oslo-middleware
    oslo-messaging
    oslo-service
    neutron-lib
    ovsdbapp;
}
