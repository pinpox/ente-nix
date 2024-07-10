{ config, pkgs, lib, ... }:
with lib;

let
  cfg = config.services.ente;
  format = pkgs.formats.yaml { };
  configFile = format.generate "local.yaml" cfg.settings;
in
{

  options.services.ente = {
    enable = mkEnableOption "ente service";

    credentialsFile = mkOption {
      default = null;
      description = /*yaml*/ ''
        # TODO
        # https://github.com/ente-io/ente/blob/main/server/scripts/compose/credentials.yaml#L10

        jwt:
            secret: "00000000000000000000000000000000000000000000"
        key:
            encryption: 00000000000000000000000000000000000000000000
            hash: 0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
        s3:
            b2-eu-cen:
                key: "0000000000000000000000000"
                secret: "0000000000000000000000000000000"
                endpoint: "000000000000000000000000000000"
                region: "00000000000"
                bucket: "00000000000"
      '';
      example = "/run/secrets/ente";
      type = with types; nullOr path;
    };

    environmentFile = mkOption {
      default = null;
      description = ''
        Environment file (see {manpage}`systemd.exec(5)` "EnvironmentFile="
        section for the syntax) passed to the service. This option can be
        used to safely include secrets in the configuration.
      '';
      example = "/run/secrets/ente";
      type = with types; nullOr path;
    };

    settings = lib.mkOption {
      default = { };
      description = ''
        ente configuration as a Nix attribute set. All settings can also be passed
        from the environment.

        See <TODO> for possible options.
      '';
      type = lib.types.submodule {
        freeformType = format.type;
        options = {

          credentials-file = lib.mkOption {
            type = lib.types.str;
            default = "${cfg.credentialsFile}";
            internal = true;
          };

          s3 = {
            b2-eu-cen = {
              endpoint = lib.mkOption {
                type = with types; str;
                default = "";
                description = ''
                  TODO
                '';
              };
              region = lib.mkOption {
                type = with types; str;
                default = "";
                description = ''
                  TODO
                '';
              };
              bucket = lib.mkOption {
                type = with types; str;
                default = "";
                description = ''
                  TODO
                '';
              };
            };
          };

          # Key used for encrypting customer emails before storing them in DB

          webauthn = {
            rpid = lib.mkOption {
              type = lib.types.str;
              default = "localhost";
              description = ''
                Our "Relying Party" ID. This scopes the generated credentials.
                See: https://www.w3.org/TR/webauthn-3/#rp-id
              '';
            };

            rporigins = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ "http://localhost:3001" ];
              description = ''
                Whitelist of origins from where we will accept WebAuthn requests.
                See: https://github.com/go-webauthn/webauthn
              '';
            };
          };

          db = {

            host = lib.mkOption {
              type = lib.types.str;
              default = "/run/postgresql";
              description = "Database host";
            };

            port = lib.mkOption {
              type = lib.types.str;
              default = "5432";
              description = "Database port";
            };

            # TODO should this be an enum?
            # See https://www.postgresql.org/docs/current/libpq-ssl.html#LIBPQ-SSL-PROTECTIONu

            sslmode = lib.mkOption {
              type = lib.types.str;
              default = "disable";
              description = "whether to enable SSL for the DB connection";
            };

            user = lib.mkOption {
              type = lib.types.str;
              default = "ente";
              description = "Database username";
            };

          };
        };
      };
    };
  };

  config = mkIf cfg.enable
    {

      services.postgresql = {
        enable = true;
        package = pkgs.postgresql_15;
        ensureUsers = [{
          name = cfg.settings.db.user;
          ensureDBOwnership = true;
        }];
        ensureDatabases = [ cfg.settings.db.user ];
      };


      # User and group
      users.users.ente = {
        isSystemUser = true;
        description = "ente user";
        extraGroups = [ "ente" ];
        group = "ente";
      };

      users.groups.ente.name = "ente";

      # Service
      systemd.services.ente = {
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        description = "ente";

        serviceConfig = {

          WorkingDirectory = "/var/lib/ente";
          BindReadOnlyPaths = [

            "${cfg.credentialsFile}:/var/lib/ente/crendentials.yaml"
            "${configFile}:/var/lib/ente/configurations/local.yaml"
            "${pkgs.museum}/share/museum/migrations:/var/lib/ente/migrations"
            "${pkgs.museum}/share/museum/mail-templates:/var/lib/ente/mail-templates"
          ];

          BindPaths = "/run/postgresql";

          EnvironmentFile = [ cfg.environmentFile ];

          User = "ente";
          ExecStart = "${lib.getExe pkgs.museum}";
          Restart = "on-failure";
          RestartSec = "5s";
        };
      };
    };
}
