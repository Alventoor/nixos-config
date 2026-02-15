{ config, piSystem, ...}:

let
  remote_password = "samba/${config.services.samba-server.remoteShare.remoteUser.name}_password";
  samba_partition_label = "SAMBA_SHARES";

in {
  imports = [
    ../../modules/samba-server.nix
  ];

  sops = {
    secrets.${remote_password} = {};
  };

  fileSystems = {
    ${config.services.samba-server.directory} = {
      device = "dev/disk/by-label/${samba_partition_label}";
      fsType = "btrfs";
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
          passwordFile = config.sops.secrets.${remote_password}.path;
        };
      };
    };

    snapper.configs = {
      samba = {
        SUBVOLUME = config.services.samba-server.directory;
        FSTYPE = "btrfs";
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
      };
    };
  };
}
