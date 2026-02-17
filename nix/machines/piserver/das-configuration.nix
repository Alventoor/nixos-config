{ config, piSystem, ...}:

let
  samba = {
    remoteUserPassword = "samba/${config.services.samba-server.remoteShare.remoteUser.name}_password";
  };

  partitionLabel = "TERRA_DAS";
  mountDirectory = "/mnt/das";

in {
  imports = [
    ../../modules/samba-server.nix
  ];

  sops = {
    secrets.${samba.remoteUserPassword} = {};
  };

  fileSystems = {
    ${mountDirectory} = {
      device = "dev/disk/by-label/${partitionLabel}";
      fsType = "btrfs";
    };

    ${config.services.samba-server.directory} = {
      device = "${mountDirectory}/samba-shares";
      fsType = "none";
      options = [ "bind" ];
    };
  };

  services = {
    samba-server = {
      enable = true;
      allowedHosts = [ "${piSystem.ipv4Network}/24" "${piSystem.ipv6Network}/64" ];

      remoteShare = {
        enable = true;

        remoteUser = {
          enable = true;
          passwordFile = config.sops.secrets.${samba.remoteUserPassword}.path;
        };
      };
    };

    snapper.configs = {
      samba = {
        SUBVOLUME = mountDirectory;
        FSTYPE = "btrfs";
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
      };
    };
  };
}
