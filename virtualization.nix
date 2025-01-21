{
  virtualisation.docker = {
    enable = true;
    rootless.enable = true;
  };

  # virtualisation.oci-containers = {
  #   backend = "docker";
  #   containers = {
  #     palworld-server = {
  #       image = "nitrog0d/palworld-arm64:latest";
  #       ports = [ "8211:8211/udp" ];
  #       environment = {
  #         ALWAYS_UPDATE_ON_START = "true";
  #         MULTITHREAD_ENABLED = "true";
  #         COMMUNITY_SERVER = "true";
  #       };
  #       volumes = [
  #         "/home/spawnhouse/palworld:/palworld"
  #       ];
  #       autoStart = true;
  #     };
  #   };
  # };
}