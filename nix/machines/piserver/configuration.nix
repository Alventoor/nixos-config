
  { config, pkgs, lib, ... }:

  let
    user = "alventoor";
    password = "$6$vBUAgT5QDFSxIMzi$rpL5SGF41P6tIDBjYWi5W0shKo.DrsWnZ8V9UawG6YRgOiy8b7E.R1rIfjZBi6TF6l6HR3wFQPIeauqXLKUui/";

    interface = "eth0";
    hostname = "piserver";
    ipv4_network = "192.168.1.0";
    ipv4_address = "192.168.1.202";
    ipv4_gateway = "192.168.1.254";
    ipv6_network = "2a01:e0a:5ac:f010::";
    ipv6_address = "2a01:e0a:5ac:f010:fcf8:a089:fa3c:2582";

    domain_name = "jl-mc.duckdns.org";

    console_keymap = "fr";
    locale = "fr_FR.UTF-8";
    time_zone = "Europe/Paris";

  in {
    # Configuration des secrets
    sops = {
      defaultSopsFile = ./secrets.yaml;
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

      secrets.duckdns_credentials = {};
    };


    # Active la mise à jour automatique du système
    system.autoUpgrade = {
      enable = true;
      allowReboot = true;
      flags = [ "--update-input" "nixpkgs" "--update-input" "sops-nix" "--update-input" "nixos-hardware" "--commit-lock-file" ];
      dates = "*-*-15,28 03:30:00";
    };

    # Paramètres du store
    nix = {
      # On utilise Nix unstable pour le support des flakes
      package = pkgs.nixUnstable;
      extraOptions = "experimental-features = nix-command flakes";

      # Nettoie les anciens paquets après chaque upgrade
      gc = {
        automatic = true;
        dates = "*-*-15,28 04:30:00";
        options = "--delete-older-than 30d";
      };
    };

    fileSystems = {
      "/" = {
        device = "/dev/disk/by-label/NIXOS_SD";
        fsType = "ext4";
        options = [ "noatime" ];
      };
    };

    # Augmente la taille du buffer des requêtes UDP
    # Cela évite de perdre des messages lors des pics de trafic
    boot.kernel.sysctl = { "net.core.rmem_max" = 1048576; };

    networking = {
      hostName = hostname;

      dhcpcd.enable = false;

      firewall = {
        # Autorise les connexions entrantes vers les divers services hébergés.
        # (DNS, site web)
        allowedUDPPorts = [ 53 80 443 ];
        allowedTCPPorts = [ 53 80 443 ];
      };

      interfaces."${interface}" = {
        # Assigne une adresse ipv4 statique
        useDHCP = false;  
        ipv4.addresses = [
          {
            address = ipv4_address;
            prefixLength = 24;
          }
        ];

        # Assigne une adresse ipv6 statique
        ipv6.addresses = [
          {
            address = ipv6_address;
            prefixLength = 64;
          }
        ];
      };

      defaultGateway = {
        address = ipv4_gateway;
        interface = interface;
      };
      nameservers = [ "127.0.0.1" "::1" ];
    };

    # On met le système en FR
    console.keyMap = console_keymap;
    i18n.defaultLocale = locale;
    time.timeZone = time_zone;

    users = {
      mutableUsers = false;

      # Désactive l'utilisateur root
      users.root.hashedPassword = "*";

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

    # Configuration du serveur ssh
    services.openssh = {
      enable = true;
      logLevel = "VERBOSE";
      permitRootLogin = "no";
    };

    # Configuration du serveur DNS
    services.unbound = {
      enable = true;
      settings = {
        server = {
          verbosity = 1;
          use-syslog = true;

          interface = [ ipv4_address ipv6_address "127.0.0.1" "::1" ];
          port = 53;

          # Liste les ordinateurs autorisés à effectuer des requêtes DNS
          access-control = [
            "127.0.0.1 allow"
            "::1 allow"
            "${ipv4_network}/24 allow"
            "${ipv6_network}/64 allow"
          ];
          do-ip4 = true;
          do-ip6 = true;
          do-udp = true;
          do-tcp = true;

          hide-identity = true;
          hide-version = true;
          harden-glue = true;
          harden-dnssec-stripped = true;
          use-caps-for-id = true;

          unwanted-reply-threshold = 10000;

          # Paramètres de performance
          num-threads = 4;
          msg-cache-slabs = 8;
          rrset-cache-slabs = 8;
          infra-cache-slabs = 8;
          key-cache-slabs = 8;
          rrset-cache-size = "100m";
          msg-cache-size = "50m";

          prefetch = true;

          # Empêche de renvoyer en réponse les adresses du réseau privé
          private-address = [
            "10.0.0.0/8"
            "172.16.0.0/12"
            "192.168.0.0/16"
            "169.254.0.0/16"
            "fd00::/8"
            "fe80::/10"
          ];

          # Autorise ce domaine à contenir des adresses du réseau privé
          private-domain = "lan";

          local-zone = "lan. static";
          local-data = [
            "\"raspberry.lan. IN A ${ipv4_address}\""
            "\"raspberry.lan. IN AAAA ${ipv6_address}\""
          ];
          local-data-ptr = [
            "\"${ipv4_address} raspberry.lan\""
            "\"${ipv6_address} raspberry.lan\""
          ];

          # Emplacement du fichier contenant les infos sur les serveurs DNS roots
          root-hints = "/etc/unbound/root.hints";
        };
      };
    };

    # Service chargé de mettre automatiquement à jour root.hints
    systemd.services.update-roothints = {
      description = "Update root.hints file for Unbound";
      serviceConfig.Type = "oneshot";
      after = [ "network.target" ];
      path = [ pkgs.curl ];
      script = ''
        curl -o /etc/unbound/root.hints https://www.internic.net/domain/named.cache
        systemctl restart unbound
      '';
    };

    # Timeur chargé d'exécuter tous les mois le service au-dessus
    systemd.timers.update-roothints = {
      description = "Update Unbound root.hints file every six months";
      wantedBy = [ "timers.target" ];
      partOf = [ "update-roothints.service" ];
      timerConfig = { 
        OnCalendar = "*-01,07-01 03:30:00";
        Unit = "update-roothints.service";
      };
    };

    # Service chargé de relever la température du processeur toutes les heures
    systemd.services.temp-monitoring = {
      description = "Log the CPU temperature";
      serviceConfig.Type = "oneshot";
      path = [ pkgs.libraspberrypi ];
      script = "vcgencmd measure_temp";
    };

    systemd.timers.temp-monitoring = {
      description = "Log the CPU temperature every 30 minutes";
      wantedBy = [ "timers.target" ];
      partOf = [ "temp-monitoring.service" ];
      timerConfig = {
        OnCalendar = "*-*-* *:00/30:00";
        Unit = "temp-monitoring.service";
      };
    };

    # Mise en place du service Vaultwarden
    services.vaultwarden = {
      enable = true;

      config = {
        signupsAllowed = false;

        # On change le port par défaut pour éviter des conflits
        rocketPort = 8812;
        rocketLog = "critical";

        websocketEnabled = true;
        websocketAddress = "0.0.0.0";
        websocketPort = 3012;

        domain = "https://vaultwarden.${domain_name}";
      };
    };

    # Génération des certificats de sécurités pour le nom de domaine
    security.acme = {
      acceptTerms = true;
      defaults.email = "julienm99@tutamail.com";

      certs."${domain_name}" = {
        group = "vaultwarden";

        extraDomainNames = [ "vaultwarden.${domain_name}" ];

        dnsProvider = "duckdns";
        webroot = null;
        credentialsFile = config.sops.secrets.duckdns_credentials.path;
      };
    };

    # Mise en place d'un reverse proxy chargé de rediriger les connexions entrantes
    # ver le serveur web
    users.users.nginx.extraGroups = [ "vaultwarden" ];
    services.nginx = {
      enable = true;

      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      # Empêche d'accéder au site web depuis les adresses non désirées
      virtualHosts."${domain_name}" = {
        default = true;

        forceSSL = true;
        enableACME = true;

        locations."/".return = "403";
      };

      # Redirige les utilisateurs vers le service vaultwarden
      virtualHosts."vaultwarden.${domain_name}" = {
        forceSSL = true;
        enableACME = true;

        locations."/" = {
          proxyPass = "http://localhost:8812";
          proxyWebsockets = true;
        };
        locations."/notifications/hub" = {
          proxyPass = "http://localhost:3012";
          proxyWebsockets = true;
        };
        locations."/notifications/hub/negotiate" = {
          proxyPass = "http://localhost:8812";
          proxyWebsockets = true;
        };
      };
    };

    # Protection fail2ban pour les services auto-hébergés
    # Une protection du service ssh est fournie par défaut par nix
    services.fail2ban = {
      enable = true;

      # Protection du service vaultwarden
      jails = {
        vaultwarden = ''
          enabled = true
          port = 80,443,881
          filter = vaultwarden
          journalmatch = _SYSTEMD_UNIT=vaultwarden.service + _COMM=vaultwarden
        '';
      };
    };

    # Filtre fail2ban pour le service vaultwarden
    environment.etc."fail2ban/filter.d/vaultwarden.local" = {
      text = ''
        [INCLUDES]
        before = common.conf

        [Definition]
        failregex = ^.*Username or password is incorrect\. Try again\. IP: <ADDR>\. Username:.*$
        ignoreregex =
      '';
    };

    # Installation manuelle des paquets
    environment.systemPackages = with pkgs; [
      # Pour la commande nslookup
      bind
      git
      gotop
      nmap
      vim
      moreutils
      libraspberrypi
      raspberrypi-eeprom
    ];

    # Configuration des paquets

    # nano
    programs.nano.nanorc = ''
      set tabstospaces
      set tabsize 2
    '';

    # git
    programs.git.config = {
      init.defaultBranch = "main";
      user = {
        name = user;
        email = "julienm99@tutamail.com";
      };
    };
  }
