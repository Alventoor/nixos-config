{ config, pkgs, lib, ... }:

let
  console_keymap = "fr";
  locale = "fr_FR.UTF-8";
  time_zone = "Europe/Paris";

  directories_to_persist =
    [ "/etc/nixos" "/var/lib" ]
    ++ lib.optional (config.services.journald.storage == "persistent") "/var/log";

  persistent_path = directory: "${cfg.persistentDirectory}${directory}";

  cfg = config.system;

in {
  options = {
    system = {
      persistentDirectory = lib.mkOption {
        type = lib.types.str;
        default = "/nix/persist";
        description = lib.mdDoc ''
          The directory containing the files needed to be preserved between system reboots.
        '';
      };
    };
  };

  config = {
    nix = {
      package = pkgs.nixVersions.latest;
      settings.experimental-features = [ "nix-command" "flakes" ];
    };

    systemd = {
      oomd.enable = false;
    };

    console.keyMap = console_keymap;
    i18n.defaultLocale = locale;
    time.timeZone = time_zone;

    environment = {
      sessionVariables = {
        XDG_CACHE_HOME = "\${HOME}/.cache";
        XDG_CONFIG_HOME = "\${HOME}/.config";
        XDG_DATA_HOME = "\${HOME}/.local/share";
        XDG_STATE_HOME = "\${HOME}/.local/state";
      };

      systemPackages = with pkgs; [
        # System
        usbutils
        gotop
        vim
        # Network
        bind # Pour la commande nslookup
        nmap
        iperf
        ethtool
        # Secrets
        sops
        ssh-to-age
      ];
    };

    # Configuration des paquets #

    programs = {
      bash.interactiveShellInit = "HISTCONTROL=ignoredups";

      nano.nanorc = ''
        set tabstospaces
        set tabsize 2
        set constantshow
      '';
    };

    # Persistent files and directories configuration #

    systemd.tmpfiles.settings."persist_directory" = builtins.listToAttrs (builtins.map (directory: {
      name = persistent_path directory;
      value = {
        d = {
          user = "root";
          group = "root";
          mode = "0755";
        };
      };
    }) directories_to_persist);

    fileSystems = builtins.listToAttrs (builtins.map (directory: {
      name = directory;
      value = {
        device = persistent_path directory;
        fsType = "none";
        options = [ "bind" ];
      };
    }) directories_to_persist);

    environment.etc = {
      "machine-id".source = "${cfg.persistentDirectory}/etc/machine-id";

      "ssh/ssh_host_rsa_key".source = "${cfg.persistentDirectory}/etc/ssh/ssh_host_rsa_key";
      "ssh/ssh_host_rsa_key.pub".source = "${cfg.persistentDirectory}/etc/ssh/ssh_host_rsa_key.pub";
      "ssh/ssh_host_ed25519_key".source = "${cfg.persistentDirectory}/etc/ssh/ssh_host_ed25519_key";
      "ssh/ssh_host_ed25519_key.pub".source = "${cfg.persistentDirectory}/etc/ssh/ssh_host_ed25519_key.pub";
    };
  };
}
