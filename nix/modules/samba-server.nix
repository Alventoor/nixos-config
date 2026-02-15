{ config, pkgs, lib, ... }:

let
  cfg = config.services.samba-server;

  default_server_directory = "/srv/samba";
  guest_user = "guest";

  users_json = builtins.toJSON (cfg.users ++ lib.optional cfg.remoteShare.remoteUser.enable
    {
      name = cfg.remoteShare.remoteUser.name;
      passwordFile = cfg.remoteShare.remoteUser.passwordFile;
    }
  );
  users_json_file = pkgs.writeText "samba-users.json" users_json;

in {
  options = {
    services.samba-server = {
      enable = lib.mkEnableOption ''
        Whether to enable the Samba file server.

        Enabling the Samba file server will also start the fail2ban service with an associated filter.
      '';

      directory = lib.mkOption {
        type = lib.types.str;
        default = default_server_directory;
        description = lib.mdDoc ''
          The directory containing the different samba shares.
        '';
      };

      allowedHosts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = lib.mdDoc ''
          The hosts allowed to access the restricted shares ('Films' and 'Privé') in addition to 'localhost'.
        '';
      };

      serverName = lib.mkOption {
        type = lib.types.str;
        default = config.networking.hostName;
        description = lib.mdDoc ''
          The name by which the Samba server is known. Limited to 15 characters.
        '';
      };

      users = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule ({ config, ...}: {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = lib.mdDoc ''
                The name of the Samba user (must match a Linux user on the system).
              '';
            };

            passwordFile = lib.mkOption {
              type = lib.types.str;
              description = lib.mdDoc ''
                The path to the file containing the Samba user's password.

                This is compatible with sops-nix.
              '';
            };
          };
        }));
      };

      allowedPrivateUsers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = lib.mdDoc ''
          The list of users allowed to access the private share.

          If empty, every user is allowed to access the share.

          For the special name rules, see the smb.conf(5) manual (valid users).
        '';
      };

      remoteShare = {
        enable = lib.mkEnableOption ''
          Whether to enable a share with unrestricted IP access, called 'Partage distant'.

          By default, the share can be accessed by all logged Samba users and, if enabled, by a shared user called '${cfg.remoteShare.remoteUser.name}'.
        '';

        remoteUser = {
          enable = lib.mkEnableOption ''
            Whether to enable a user called '${cfg.remoteShare.remoteUser.name}', with access to the remote share.
          '';

          name = lib.mkOption {
            type = lib.types.str;
            default = "distant";
            description = lib.types.mdDoc ''
              The name of the remote share associated user account.
            '';
          };

          passwordFile = lib.mkOption {
            type = lib.types.str;
            description = lib.mdDoc ''
              The path to the file containing the remote user's password.

              This is compatible with sops-nix.
            '';
          };

          writePermissions = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = lib.types.mdDoc ''
              Whether to give the remote user the permissions to write inside the share directory.
            '';
          };
        };

        allowedUsers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = lib.mdDoc ''
            The list of users allowed to access the remote share, in addition to the remote user if enabled.

            If empty, every user is allowed to access the share.

            For the special name rules, see the smb.conf(5) manual (valid users).
          '';
        };

        writeGroup = lib.mkOption {
          type = lib.types.str;
          default = "remote_share_write";
          description = lib.mdDoc ''
            The name of the required group for write permissions on the remote share.
          '';
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services = {
      # To make the server discoverable
      avahi = {
        enable = true;
        openFirewall = true;

        publish.enable = true;
        publish.userServices = true;
        nssmdns4 = true;
      };

      samba = {
        package = pkgs.samba4Full;
        enable = true;
        openFirewall = true;

        settings = {
          global = {
            "netbios name" = cfg.serverName;
            "server string" = "Serveur Samba de ${cfg.serverName}";

            "security" = "user";
            
            "logging" = "systemd";
            "log level" = "0 auth_json_audit:2";

            "guest account" = guest_user;

            "inherit owner" = "yes";
            "inherit permissions" = "yes";
          };

          "Films" = {
            "hosts allow" = "${builtins.concatStringsSep " " cfg.allowedHosts} localhost";
            "path" = "${cfg.directory}/movies";
            "public" = "yes";
            "browseable" = "yes";
            "writeable" = "yes";
          };

          "Privé" = {
            "hosts allow" = "${builtins.concatStringsSep " " cfg.allowedHosts} localhost";
            "path" = "${cfg.directory}/private";
            "public" = "no";
            "browseable" = "yes";
            "writeable" = "yes";
            "valid users" = builtins.concatStringsSep " " cfg.allowedPrivateUsers;
          };

          "Partage distant" = lib.mkIf cfg.remoteShare.enable {
            "path" = "${cfg.directory}/remote";
            "public" = "no";
            "browseable" = "yes";
            "writeable" = "yes";
            "write list" = "@${cfg.remoteShare.writeGroup}";

            # If the share is only allowed to some users (allowedUsers is not empty) we also add the remote user to he valid users
            "valid users" = lib.mkIf (cfg.remoteShare.allowedUsers != []) (builtins.concatStringsSep " " (cfg.remoteShare.allowedUsers ++ lib.optional cfg.remoteShare.remoteUser.enable cfg.remoteShare.remoteUser.name));
          };
        };
      };
    
      samba-wsdd = {
        enable = true;
        openFirewall = true;
      };
    };

    # Users creation #

    users = {
      groups = lib.mkMerge [
        { ${guest_user} = {}; }
        (lib.mkIf cfg.remoteShare.enable { ${cfg.remoteShare.writeGroup} = {}; })
        (lib.mkIf cfg.remoteShare.remoteUser.enable { ${cfg.remoteShare.remoteUser.name} = {}; })
      ];

      users = lib.mkMerge [
        {
          ${guest_user} = {
            description = "Invité samba";
            isSystemUser = true;
            group = guest_user;
          };
        }
        (lib.mkIf cfg.remoteShare.remoteUser.enable {
          ${cfg.remoteShare.remoteUser.name} = {
            description = "Utilisateur samba distant";
            isSystemUser = true;
            group = cfg.remoteShare.remoteUser.name;
            extraGroups = lib.mkIf cfg.remoteShare.remoteUser.writePermissions [ cfg.remoteShare.writeGroup ];
          };
        })
      ];
    };

    systemd.services.samba-users-creation = {
      description = "Samba SMB user creation service";
      
      serviceConfig.Type = "oneshot";
      wantedBy = [ "multi-user.target" ];
      before = [ "samba.target" ];

      path = [pkgs.jq pkgs.samba4Full];
      script = ''
        users=$(jq -r 'keys[]' ${users_json_file})

        while IFS= read -r userId; do
          userName=$(jq -r ".[$userId].name" ${users_json_file})
          passwordFile=$(jq -r ".[$userId].passwordFile" ${users_json_file})
          password=$(cat $passwordFile)

          echo "Creating samba user '$userName'..."

          #smbpasswd ask password twice
          printf "$password\n$password\n" | smbpasswd -sa $userName

          status=$?
          [ $status -eq 0 ] && echo "done"
        done <<< "$users"
      '';
    };

    #Fail2ban Protection #

    services.fail2ban = {
      enable = true;

      jails = {
        samba = ''
          enabled = true
          port = 139,445
          maxretry = 5
          bantime = 1d
          filter = samba
          journalmatch = _SYSTEMD_UNIT=samba-smbd.service + _COMM=smbd
        '';
      };
    };

    environment.etc = {
      "fail2ban/filter.d/samba.local" = {
        text = ''
          [INCLUDES]
          before = common.conf

          [Definition]
          failregex = status": "(NT_STATUS_WRONG_PASSWORD|NT_STATUS_NO_SUCH_USER)",.*remoteAddress": "ipv(4|6):<ADDR>:
        '';
      };
    };
  };
}
