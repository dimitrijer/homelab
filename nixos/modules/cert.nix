{ config, modulesPath, agenix, ... }:

{
  imports = [ "${agenix}/modules/age.nix" ];

  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "templaryum@gmail.com";
      dnsProvider = "namecheap";
      credentialsFile = config.age.secrets.namecheap-ini.path;
      # Cannot use system resolver since it's going to resolve to local addresses.
      dnsResolver = "1.1.1.1:53";
    };
  };

  age.secrets.namecheap-ini.file = ../../secrets/namecheap.ini.age;
  age.identityPaths = [ "/etc/ssh/ssh_host_rsa_key" ];
}
