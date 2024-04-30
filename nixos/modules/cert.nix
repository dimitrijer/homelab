{ modulesPath, ... }:
{
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "templaryum@gmail.com";
      dnsProvider = "namecheap";
      credentialsFile = "/etc/namecheap.ini";
      # Cannot use system resolver since it's going to resolve to local addresses.
      dnsResolver = "1.1.1.1:53";
    };
  };

  environment.etc."namecheap.ini" = {
    text = ''
      NAMECHEAP_API_USER=dimitrijer
      NAMECHEAP_API_KEY=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
    '';
  };
}
