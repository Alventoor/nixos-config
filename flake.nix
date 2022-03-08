{
  inputs.sops-nix.url = github:Mic92/sops-nix;
  inputs.nixos-hardware.url = github:NixOS/nixos-hardware/master;

  outputs = { self, nixpkgs, sops-nix, nixos-hardware }: {
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
  };
}

