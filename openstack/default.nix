{ pkgs }:

let
  python = pkgs.python3;

  # Import python-ovs from ovn directory
  python-ovs = pkgs.callPackage ../ovn/python-ovs.nix {
    inherit (python.pkgs) buildPythonPackage fetchPypi setuptools sortedcontainers;
  };

  callPackage = pkgs.newScope (self // {
    inherit (pkgs) fetchFromGitHub;
    inherit (python.pkgs) buildPythonPackage fetchPypi setuptools pbr;
    inherit (python.pkgs) oslo-concurrency oslo-config oslo-context oslo-db oslo-i18n oslo-log oslo-metrics oslo-serialization oslo-utils;
    inherit (python.pkgs) keystoneauth1 osprofiler pecan sqlalchemy stevedore webob;
    inherit (python.pkgs) amqp bcrypt cachetools cffi debtcollector eventlet fixtures greenlet jinja2 iso8601;
    inherit (python.pkgs) kombu msgpack ncclient netaddr paste pastedeploy prettytable pyyaml requests routes;
    inherit (python.pkgs) setproctitle sortedcontainers statsd yappi;
  });

  self = {
    # OVS Python bindings (from ovn directory)
    ovs = python-ovs;

    # Oslo libraries
    oslo-rootwrap = callPackage ./oslo-rootwrap.nix { };

    oslo-privsep = callPackage ./oslo-privsep.nix { };

    futurist = callPackage ./futurist.nix { };

    oslo-middleware = callPackage ./oslo-middleware.nix { };

    oslo-service = callPackage ./oslo-service.nix {
      oslo-privsep = self.oslo-privsep;
    };

    oslo-messaging = callPackage ./oslo-messaging.nix {
      futurist = self.futurist;
      oslo-middleware = self.oslo-middleware;
      oslo-service = self.oslo-service;
    };

    oslo-policy = callPackage ./oslo-policy.nix { };

    oslo-versionedobjects = callPackage ./oslo-versionedobjects.nix {
      oslo-messaging = self.oslo-messaging;
    };

    # OpenStack utilities
    os-traits = callPackage ./os-traits.nix { };

    os-ken = callPackage ./os-ken.nix {
      ovs = self.ovs;
    };

    # OVS and Neutron libraries
    ovsdbapp = callPackage ./ovsdbapp.nix {
      ovs = self.ovs;
    };

    neutron-lib = callPackage ./neutron-lib.nix {
      os-ken = self.os-ken;
      oslo-messaging = self.oslo-messaging;
      oslo-policy = self.oslo-policy;
      oslo-versionedobjects = self.oslo-versionedobjects;
      os-traits = self.os-traits;
      oslo-service = self.oslo-service;
    };
  };
in
self
