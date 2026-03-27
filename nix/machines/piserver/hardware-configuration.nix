{config, ...}:

{
  boot.loader.raspberry-pi.bootloader = "kernel";

  hardware.raspberry-pi.config = {
    all = {
      dt-overlays = {
        disable-bt-pi5 = {
          enable = true;
        };

        disable-wifi-pi5 = {
          enable = true;
        };
      };
    };
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" ];
    };

    "/boot/firmware" = {
      device = "/dev/disk/by-label/FIRMWARE";
      fsType = "vfat";
    };
  };
}
