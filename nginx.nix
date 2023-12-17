{ pkgs }:

let
  nginxPort = "8080";
  nginxWebRoot = "/srv/http";

  nginxConf = pkgs.writeText "nginx.conf" ''
    user nobody nobody;
    daemon off;
    error_log /dev/stdout info;
    pid /dev/null;
    events {}
    http {
      access_log /dev/stdout;
      server {
        listen ${nginxPort};
        index index.html;
        charset utf-8;

        add_header X-Frame-Options "SAMEORIGIN";
        add_header X-Content-Type-Options "nosniff";
        location / {
          root ${nginxWebRoot};
          try_files $uri $uri.html $uri/ =404;
        }
      }
    }
  '';
in
pkgs.dockerTools.buildLayeredImage {
  name = "nginx";
  tag = "latest";

  contents = [
    pkgs.fakeNss
    pkgs.nginx
    pkgs.bash
    pkgs.coreutils
    pkgs.procps
    pkgs.iputils
    (pkgs.writeScriptBin "start-server" ''
      #!${pkgs.runtimeShell}
      nginx -c ${nginxConf};
    '')
  ];

  extraCommands = ''
    find -type l -exec bash -c 'target=$(readlink -m "$0"); (( ''${#target} >= 100 )) && unlink "$0" && cp "$target" "$0"' {} \;
    mkdir -p var/log/nginx
    mkdir -p var/cache/nginx
    mkdir -p tmp
    chmod 1777 tmp
  '';

  config = {
    Cmd = [ "start-server" ];
    ExposedPorts = {
      "${nginxPort}/tcp" = { };
    };
  };
}
