{ config, pkgs, ... }:

let
  console_keymap = "fr";
  locale = "fr_FR.UTF-8";
  time_zone = "Europe/Paris";

in {
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

  # Installation des paquets
  environment = {
    sessionVariables = {
      XDG_CACHE_HOME = "\${HOME}/.cache";
      XDG_CONFIG_HOME = "\${HOME}/.config";
      XDG_DATA_HOME = "\${HOME}/.local/share";
      XDG_STATE_HOME = "\${HOME}/.local/state";
    };

    systemPackages = with pkgs; [
      # System
      gotop
      vim
      # Network
      bind # Pour la commande nslookup
      nmap
      # Secrets
      sops
      ssh-to-age
    ];
  };

  # Configuration des paquets

  programs.bash.interactiveShellInit = "HISTCONTROL=ignoredups";

  programs.nano.nanorc = ''
    set tabstospaces
    set tabsize 2
  '';
}
