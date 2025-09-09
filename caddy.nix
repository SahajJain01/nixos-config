{ config, lib, pkgs, ... }:

{
  services.caddy = {
    enable = true;
    email = "contact@sahajjain.com";
    virtualHosts."calendar.sahajjain.com".extraConfig = ''
      encode zstd gzip
      header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
      }
      reverse_proxy 127.0.0.1:3000
    '';
  };
}
  
