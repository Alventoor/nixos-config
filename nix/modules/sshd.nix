{ config, pkgs, ... }:
{
  services.openssh = {
    enable = true;
    logLevel = "VERBOSE";
    permitRootLogin = "no";
  };

  # Activation de la protection fail2ban
  # Une protection est fournie par défaut pour le service ssh
  services.fail2ban.enable = true;
}
