{ config, piSystem, lib, ...}:

let
  cfg = config.piSystem.das;

  samba = {
    remoteUserPassword = "samba/${config.services.samba-server.remoteShare.remoteUser.name}_password";
  };

  backupDirectory = "${cfg.mountDirectory}/backup";

in {
  imports = [
    ../../modules/samba-server.nix
  ];

  options = {
    piSystem.das = {
      mountDirectory = lib.mkOption {
        type = lib.types.path;
        default = "/mnt/das";
        description = lib.mdDoc ''
          The directory where the das is mounted.
        '';
      };
    };
  };

  config = {
    sops = {
      secrets.${samba.remoteUserPassword} = {};
    };

    fileSystems = {
      ${config.services.samba-server.directory} = {
        device = "${cfg.mountDirectory}/samba-shares";
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

      vaultwarden.backupDir = "${backupDirectory}/vaultwarden";

      snapper.configs = {
        das = {
          SUBVOLUME = cfg.mountDirectory;
          FSTYPE = "btrfs";
          TIMELINE_CREATE = true;
          TIMELINE_CLEANUP = true;
        };
      };
    };
  };
}
