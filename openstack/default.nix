# OpenStack python libraries that nixpkgs does not ship (or ships in a form
# that does not work for ovn-bgp-agent).
{ pkgs }:

let
  python = pkgs.python3;

  callPackage = pkgs.newScope (self // {
    inherit (pkgs) fetchFromGitHub;
    inherit (python.pkgs) buildPythonPackage fetchPypi setuptools pbr;
    inherit (python.pkgs) oslo-concurrency oslo-config oslo-context oslo-db oslo-i18n oslo-log oslo-metrics oslo-serialization oslo-utils;
    inherit (python.pkgs) keystoneauth1 osprofiler pecan sqlalchemy stevedore webob;
    inherit (python.pkgs) amqp bcrypt cachetools cffi debtcollector eventlet fixtures greenlet jinja2 iso8601;
    inherit (python.pkgs) kombu msgpack ncclient netaddr paste pastedeploy prettytable pyyaml requests routes;
    inherit (python.pkgs) setproctitle sortedcontainers statsd yappi;
    # Test dependencies
    inherit (python.pkgs) stestr oslotest testtools testscenarios requests-mock jsonschema testresources hacking confluent-kafka;
  });

  self = {
    # OVS python bindings
    ovs = callPackage ./ovs.nix { };

    # Oslo libraries
    oslo-rootwrap = callPackage ./oslo-rootwrap.nix { };
    oslo-privsep = callPackage ./oslo-privsep.nix { };
    futurist = callPackage ./futurist.nix { };
    oslo-middleware = callPackage ./oslo-middleware.nix { };
    oslo-service = callPackage ./oslo-service.nix { };
    oslo-messaging = callPackage ./oslo-messaging.nix { };
    oslo-policy = callPackage ./oslo-policy.nix { };
    oslo-versionedobjects = callPackage ./oslo-versionedobjects.nix { };

    # OpenStack utilities
    os-traits = callPackage ./os-traits.nix { };
    os-ken = callPackage ./os-ken.nix { };

    # OVS and Neutron libraries
    ovsdbapp = callPackage ./ovsdbapp.nix { };
    neutron-lib = callPackage ./neutron-lib.nix { };
  };
in
self
