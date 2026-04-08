{config, ...}:

let
  dasPartitionLabel = "TERRA_DAS";

in {
  boot = {
    initrd.kernelModules = [ "cryptd" ];

    loader.raspberry-pi.bootloader = "kernel";
  };

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

    ${config.piSystem.das.mountDirectory} = {
      device = "/dev/mapper/${dasPartitionLabel}";
      fsType = "btrfs";
    };
  };

  environment.etc.crypttab = {
    mode = "0600";
    text = ''
      # <volume-name> <encrypted-device> [key-file] [options]
      ${dasPartitionLabel} /dev/disk/by-label/${dasPartitionLabel} ${config.piServer.das.luksKeyPath}
    '';
  };
}
