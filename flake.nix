{
  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/nixos-unstable;

    sops-nix.url = github:Mic92/sops-nix;
    nixos-raspberrypi.url = github:nvmd/nixos-raspberrypi/main;

    private.url = git+file:/etc/nixos/nix/private;
  };

  nixConfig = {
    extra-substituters = [
      "https://nixos-raspberrypi.cachix.org"
    ];
    extra-trusted-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYlNOA5sPI="
    ];
  };

  outputs = { self, nixpkgs, sops-nix, nixos-raspberrypi, private }: {

    nixosConfigurations.piserver = nixos-raspberrypi.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        # Permet l'utilisation de fichiers cryptés pour les paramètres systèmes
        sops-nix.nixosModules.sops
        # Ajoute le support des fonctionnalités spécifiques au Raspberry Pi 5
        nixos-raspberrypi.nixosModules.raspberry-pi-5.base
        nixos-raspberrypi.nixosModules.raspberry-pi-5.page-size-16k
        private.nixosModules.piserver.samba-private-users
        # Fichier de configuration du système
        ./nix/machines/piserver/configuration.nix
      ];
    };

    nixosConfigurations.quark = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [
        sops-nix.nixosModules.sops
        private.nixosModules.quark
        ./nix/machines/quark/configuration.nix
      ];
    };
  };
}

