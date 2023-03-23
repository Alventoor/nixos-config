# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

let
  hostname = "quark";
  user = "alventoor";
  user_extraGroups = [ "gaming" ];

in {
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../modules/base.nix
      ../../modules/head.nix
      ../../modules/firefox.nix
      ../../modules/minecraft-server.nix
    ];

  sops = {
    defaultSopsFile = ./secrets.yaml;
    age.sshKeyPaths = [ "/nix/persist/etc/ssh/ssh_host_ed25519_key" ];

    secrets.alventoor_password = {
      neededForUsers = true;
    };
  };

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;

    loader = {
      efi.canTouchEfiVariables = true;

      grub = {
        enable = true;
        efiSupport = true;
        useOSProber = true;

        # mirroredBoots allows to install grub to another path than /boot
        mirroredBoots = [
          {
            devices = [ "nodev" ];
            path = "/nix/state/bootloader";
            efiSysMountPoint = "/efi";
          }
        ];
      };
    };
  };

  nix.settings.auto-optimise-store = true;
  nixpkgs.config.allowUnfree = true;

  networking = {
    hostName = hostname;
 
    # The global useDHCP flag is deprecated, therefore explicitly set to false here.
    # Per-interface useDHCP will be mandatory in the future, so this generated config
    # replicates the default behaviour.
    useDHCP = false;
    interfaces.enp0s2.useDHCP = true;
  };

  users = {
    mutableUsers = false;

    groups = {
      gaming = {};
    };

    users."${user}" = {
      isNormalUser = true;
      extraGroups = [ "wheel" ] ++ user_extraGroups;
      passwordFile = config.sops.secrets.alventoor_password.path;
    };
  };

  environment.etc = {
    "machine-id".source = "/nix/persist/etc/machine-id";

    "ssh/ssh_host_rsa_key".source = "/nix/persist/etc/ssh/ssh_host_rsa_key";
    "ssh/ssh_host_rsa_key.pub".source = "/nix/persist/etc/ssh/ssh_host_rsa_key.pub";
    "ssh/ssh_host_ed25519_key".source = "/nix/persist/etc/ssh/ssh_host_ed25519_key";
    "ssh/ssh_host_ed25519_key.pub".source = "/nix/persist/etc/ssh/ssh_host_ed25519_key.pub";
  };

  services = {
    fstrim.enable = true;
    journald.extraConfig = "SystemMaxUse=1G";

    xserver = {
      displayManager.sddm.enable = true;
      desktopManager.plasma5 = {
        enable = true;

        excludePackages = with pkgs.libsForQt5; [
          oxygen
        ];
      };
    };

    minecraft-server = {
      enable = true;
      bindFolder = true;
      dataDir = "/home/games/minecraft-server";
      admins = [ user ];
    };
  };

  programs = {
    # Don't work if enabled from environment.systemPackages
    partition-manager.enable = true;
    java.enable = true;

    steam = {
      enable = true;
      remotePlay.openFirewall = true;
    };
  };

  environment.systemPackages = with pkgs; [
    helvum
    wireshark
    # plasma
    ark
    kate
    skanpage
    filelight
    kcalc
    kcolorchooser
    # apps
    mpv
    qbittorrent
    teamspeak_client
    discord
    krita
    # libreoffice
    libreoffice-qt
    hunspell
    hunspellDicts.fr-moderne
    hunspellDicts.en_US
    # theming
    papirus-icon-theme
    # dev
    git
    jetbrains.idea-community
    rustc
    cargo
    qemu
  ];

  fonts.fonts = with pkgs; [
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
    hack-font
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.05"; # Did you read the comment?

}
