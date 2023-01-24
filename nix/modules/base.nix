{ config, pkgs, ... }:

let
  console_keymap = "fr";
  locale = "fr_FR.UTF-8";
  time_zone = "Europe/Paris";

in {
  nix = {
    # On utilise Nix unstable pour le support des flakes
    package = pkgs.nixUnstable;
    extraOptions = "experimental-features = nix-command flakes";
  };

  console.keyMap = console_keymap;
  i18n.defaultLocale = locale;
  time.timeZone = time_zone;

  # Installation des paquets
  environment.systemPackages = with pkgs; [
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

  # Configuration des paquets

  programs.bash.interactiveShellInit = "HISTCONTROL=ignoredups";

  programs.nano.nanorc = ''
    set tabstospaces
    set tabsize 2
  '';
}
