{config, ...}:

let
  pi_version = "4";

in {
  hardware = {
    raspberry-pi.${pi_version}.apply-overlays-dtmerge.enable = true;

    deviceTree = {
      enable = true;
      filter = "bcm2711-rpi-4-b.dtb";

      # From the overlays at https://github.com/raspberrypi/linux/<..>/arch/arm/boot/dts/overlays
      overlays = [
        # Based on disable-wifi-overlays.dts
        {
          name = "disable-wifi";
          dtsText = ''
            /dts-v1/;
            /plugin/;
            /{
                compatible = "brcm,bcm2711";

                fragment@0 {
                    target = <&mmc>;
                    __overlay__ {
                        status = "disabled";
                    };
                };

                fragment@1 {
                    target = <&mmcnr>;
                    __overlay__ {
                        status = "disabled";
                    };
                };
            };
          '';
        }

        # Based on disable-bt-overlays.dts
        {
          name = "disable-bt";
          dtsText = ''
            /dts-v1/;
            /plugin/;
            /{
                compatible = "brcm,bcm2711";

                fragment@0 {
                    target = <&bt>;
                    __overlay__ {
                        status = "disabled";
                    };
                };
            };
          '';
        }
      ];
    };
  };
}
