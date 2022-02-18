
  { config, pkgs, lib, ... }:

  let
    user = "alventoor";
    password = "$6$vBUAgT5QDFSxIMzi$rpL5SGF41P6tIDBjYWi5W0shKo.DrsWnZ8V9UawG6YRgOiy8b7E.R1rIfjZBi6TF6l6HR3wFQPIeauqXLKUui/";

    interface = "eth0";
    hostname = "piserver";
    ipv4_network = "192.168.1.0";
    ipv4_address = "192.168.1.202";
    ipv4_gateway = "192.168.1.254";

    console_keymap = "fr";
    locale = "fr_FR.UTF-8";
    time_zone = "Europe/Paris";

  in {
    # On utilise Nix unstable pour le support des flakes
    nix = {
      package = pkgs.nixUnstable;
      extraOptions = "experimental-features = nix-command flakes";
    };

    fileSystems = {
      "/" = {
        device = "/dev/disk/by-label/NIXOS_SD";
        fsType = "ext4";
        options = [ "noatime" ];
      };
    };

    networking = {
      hostName = hostname;

      dhcpcd.enable = false;

      # Assigne une adresse statique
      interfaces."${interface}" = {
        useDHCP = false;  
        ipv4.addresses = [
          {
            address = ipv4_address;
            prefixLength = 24;
          }
        ];
      };

      defaultGateway = {
        address = ipv4_gateway;
        interface = interface;
      };
      nameservers = [ "127.0.0.1" "::1" ];
    };

    services.openssh.enable = true;

    # On met le système en FR
    console.keyMap = console_keymap;
    i18n.defaultLocale = locale;
    time.timeZone = time_zone;

    users = {
      mutableUsers = false;
      users."${user}" = {
        isNormalUser = true;
        hashedPassword = password;
        extraGroups = [ "wheel" ];
      };
    };

    # Configure le profil bash
    programs.bash.shellInit = "HISTCONTROL=ignoredups";

    # Enable GPU acceleration
    hardware.raspberry-pi."4".fkms-3d.enable = true;

    # Configuration du serveur DNS
    services.unbound = {
      enable = true;
      settings = {
        server = {
          verbosity = 1;
          use-syslog = true;

          interface = [ "127.0.0.1" "::1" ];
          port = 53;

          # Liste les ordinateurs autorisés à effectuer des requêtes DNS
          access-control = [ "${ipv4_network}/24 allow" ];
          do-ip4 = true;
          do-ip6 = true;
          do-udp = true;
          do-tcp = true;

          hide-identity = false;
          hide-version = true;
          harden-glue = true;

          so-rcvbuf = "1m";
          # Empêche de renvoyer en réponse les adresses du réseau privé
          private-address = [ "${ipv4_network}/24" ];

          unwanted-reply-threshold = 10000;

          # Emplacement du fichier contenant les infos sur les serveurs DNS roots
	  root-hints = "/etc/unbound/root.hints";
        };
      };
    };

    # Service chargé de mettre automatiquement à jour root.hints
    systemd.services.update-roothints = {
      serviceConfig.Type = "oneshot";
      after = [ "network.target" ];
      path = [ pkgs.curl ];
      script = "curl -o /etc/unbound/root.hints https://www.internic.net/domain/named.cache";
    };

    # Timeur chargé d'exécuter tous les mois le service au-dessus
    systemd.timers.update-roothints = {
      wantedBy = [ "timers.target" ];
      partOf = [ "update-roothints.service" ];
      timerConfig = { 
        OnCalendar = "monthly";
        Unit = "update-roothints.service";
      };
    };

    # Installation manuelle des paquets
    environment.systemPackages = with pkgs; [
      # Pour la commande nslookup
      bind
      git
      gotop
      vim
    ];

    # Configuration des paquets

    # nano
    programs.nano.nanorc = ''
      set tabstospaces
      set tabsize 2
    '';

    # Nettoie les anciens paquets toutes les 2 semaines
    nix.gc.automatic = true;
    nix.gc.dates = "2weeks";
  }
