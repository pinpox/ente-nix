{
  description = "Fully open source, End to End Encrypted alternative to Google Photos and Apple Photos ";

  # Nixpkgs / NixOS version to use.

  inputs.nixpkgs.url = "github:pinpox/nixpkgs/init-ente-server";
  # inputs.nixpkgs.url = "nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let

      version = "photos-v0.9.5";

      # System types to support.
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; });


    in
    {

      nixosModule = ({ pkgs, ... }: {
        imports = [ ./module.nix ];
        # defined overlays injected by the nixflake
        nixpkgs.overlays = [
          (_self: _super: {
            # museum = self.packages.${pkgs.system}.museum;
          })
        ];
      });

      # Provide some binary packages for selected system types.
      packages = forAllSystems (system:
        let
          pkgs = nixpkgsFor.${system};

          ente-src = pkgs.fetchFromGitHub {
            owner = "ente-io";
            repo = "ente";
            rev = version;
            hash = "sha256-X27fmLg6pUBFf8om3fQ1rILicxoFKPMISG2agr7m+nc=";
          };
        in
        {
          ente-cli = pkgs.buildGoModule {
            version = "cli-v0.1.16";

            pname = "ente";

            src = "${ente-src}/cli";

            meta = with pkgs.lib; {
              description = "CLI for ente.io";
              homepage = "https://github.com/ente-io/ente/tree/main/cli";
              license = licenses.agpl3Only;
              maintainers = with maintainers; [ surfaceflinger pinpox ];
              mainProgram = "cli";
              platforms = platforms.linux;
            };

            vendorHash = "sha256-Gg1mifMVt6Ma8yQ/t0R5nf6NXbzLZBpuZrYsW48p0mw=";
          };

          ente-photos-desktop-appimage =
            let
              pname = "ente-photos-desktop";
              version = "1.7.2-rc";
              shortName = "ente";
              applicationName = "Ente";
              name = "${shortName}-${version}";

              mirror = "https://github.com/ente-io/photos-desktop/releases/download";
              src = pkgs.fetchurl {
                url = "${mirror}/v${version}/${name}-x86_64.AppImage";
                hash = "sha256-riBa8vgERy2gi1bVWSHQzO+7YZhIuVc7j2R3aEgmoUs=";
              };

              appimageContents = pkgs.appimageTools.extractType2 { inherit name src; };
            in
            pkgs.appimageTools.wrapType1 {
              inherit name src;

              extraPkgs = pkgs: with pkgs; [ fuse ];

              extraInstallCommands = ''
                mv $out/bin/${name} $out/bin/${pname}

                install -m 444 -D ${appimageContents}/${shortName}.desktop $out/share/applications/${pname}.desktop
                substituteInPlace $out/share/applications/${pname}.desktop \
                  --replace 'Exec=AppRun' "Exec=$out/bin/${pname}"
                substituteInPlace $out/share/applications/${pname}.desktop \
                  --replace 'Name=ente' "Name=${applicationName}"
                cp -r ${appimageContents}/usr/share/icons $out/share
              '';

              meta = with pkgs.lib; {
                description = "Fully open source, End to End Encrypted alternative to Google Photos and Apple Photos";
                mainProgram = "ente-photos-desktop";
                homepage = "https://github.com/ente-io/photos-desktop";
                license = licenses.mit;
                # maintainers = [ pinpo }];
                platforms = [ "x86_64-linux" ];
              };
            };



        });

    };
}
