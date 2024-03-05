{ config, pkgs, ... }:

let keyboard_layout = "fr";

in {
  security = {
    polkit.enable = true;

    # Pour pipewire
    rtkit.enable = true;
  };

  services.printing = {
    enable = true;
    drivers = [ pkgs.hplip ];
  };

  services.xserver = {
    enable = true;
    xkb.layout = keyboard_layout;
  };

  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
  };

  xdg.portal.enable = true;
}
