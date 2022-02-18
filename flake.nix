{
  inputs.nixos-hardware.url = github:NixOS/nixos-hardware/master;

  outputs = { self, nixpkgs, nixos-hardware }: {
    nixosConfigurations.piserver = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        # Ajoute le support des fonctionnalités spécifiques au Raspberry Pi 4
        nixos-hardware.nixosModules.raspberry-pi-4

        # Fichier de configuration du système 
        ./nix/machines/pi_server.nix
      ];
    };
  };
}

