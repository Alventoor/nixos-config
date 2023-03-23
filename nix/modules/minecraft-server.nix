{ lib, config, ... }:

let
  cfg = config.services.minecraft-server;

  defaultDataDir = "/srv/minecraft-server";

  adminsExtraGroup = builtins.map (x:
    { name = "${x}"; value = { extraGroups = [ "minecraft" ]; }; }
  ) cfg.admins;
in {
  options = {
    services.minecraft-server = {
      bindFolder = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = lib.mdDoc ''
          If enabled, bind the dataDir folder to the server's view of the file system.
          It's necessary if you want to use a directory located under /home as the service
          can't directly read inside.
        '';
      };

      admins = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = lib.mdDoc ''
          The users with read and write access to the server config files.
          These users will be added to the "minecraft" group.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.minecraft-server = {
      eula = true;
      declarative = true;
      openFirewall = true;
      dataDir = lib.mkDefault defaultDataDir;
      #TODO Up to 8GB
      jvmOpts = "-Xmx2048M -Xms2048M";

      serverProperties = {
        difficulty = "normal";
        enable-command-block = true;
        max-players = 4;
        view-distance = 12;
        simulation-distance = 12;
      };
    };

    systemd.services.minecraft-server = {
      # Disable the server start at boot
      wantedBy = lib.mkForce [];

      serviceConfig = {
        # Allow users in minecraft group to read/write server config
        UMask = lib.mkForce "0007";

        ProtectHome = lib.mkIf cfg.bindFolder (lib.mkForce "tmpfs");
        BindPaths = lib.mkIf cfg.bindFolder [ "${cfg.dataDir}" ];
      };
    };

    users.users = lib.mkMerge [
      # Allow users in minecraft group to access server folder
      { minecraft.homeMode = "770";
      }

      (builtins.listToAttrs adminsExtraGroup)
    ];
  };
}
