{
  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/nixos-unstable;

    sops-nix.url = github:Mic92/sops-nix;
    nixos-hardware.url = github:NixOS/nixos-hardware/master;

    private.url = git+file:/etc/nixos/nix/private;
  };

  outputs = { self, nixpkgs, sops-nix, nixos-hardware, private }: {

    nixosConfigurations.piserver = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        # Permet l'utilisation de fichiers cryptés pour les paramètres systèmes
        sops-nix.nixosModules.sops
        # Ajoute le support des fonctionnalités spécifiques au Raspberry Pi 4
        nixos-hardware.nixosModules.raspberry-pi-4
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

