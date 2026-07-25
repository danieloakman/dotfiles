{ config, lib, ... }:
let
  cfg = config.my.services.pia;
  caPath = "/etc/openvpn/pia-ca.rsa.4096.crt";

  # Streaming Optimized endpoints are the same OpenVPN/NM shape as regular
  # ones; only the remote hostname differs (PIA routes them to a different pool).
  mkOpenVpnProfile =
    { id
    , uuid
    , remote
    }:
    {
      connection = {
        inherit id uuid;
        type = "vpn";
        autoconnect = "false";
      };
      vpn = {
        service-type = "org.freedesktop.NetworkManager.openvpn";
        username = "$PIA_USERNAME";
        comp-lzo = "no";
        inherit remote;
        cipher = "AES-256-CBC";
        auth = "SHA256";
        connection-type = "password";
        password-flags = "0";
        port = "1197";
        proto-tcp = "no";
        ca = caPath;
      };
      vpn-secrets = {
        password = "$PIA_PASSWORD";
      };
      ipv4 = {
        method = "auto";
      };
    };
in
{
  options.my.services.pia = {
    enable = lib.mkEnableOption "Enable Private Internet Access NetworkManager VPN profiles";
    profiles = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            id = lib.mkOption {
              type = lib.types.str;
              description = "NetworkManager connection display name.";
            };
            uuid = lib.mkOption {
              type = lib.types.str;
              description = "Stable connection UUID.";
            };
            remote = lib.mkOption {
              type = lib.types.str;
              description = ''
                OpenVPN remote setting as NetworkManager expects it, e.g.
                `au-sydney.privacy.network 1197 udp`.
              '';
            };
          };
        }
      );
      default = {
        PIA-AU_Sydney = {
          id = "PIA-AU_Sydney";
          uuid = "07cd5a3e-8d88-49d3-9ac7-696f1a955f7e";
          remote = "au-sydney.privacy.network 1197 udp";
        };
        PIA-Australia_Streaming_Optimized = {
          id = "PIA-Australia_Streaming_Optimized";
          uuid = "2a1f6a07-0633-45df-9e9a-fe517895ba00";
          remote = "au-australia-so.privacy.network 1197 udp";
        };
      };
      description = "Curated PIA OpenVPN NetworkManager profiles to declare.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Public PIA CA from their OpenVPN config bundle — safe to ship in-repo.
    environment.etc."openvpn/pia-ca.rsa.4096.crt".source =
      ./pia-ca.rsa.4096.crt;

    # ensureProfiles uses envsubst; EnvironmentFile needs KEY=value lines.
    sops.templates."pia-nm.env" = {
      content = ''
        PIA_USERNAME=${config.sops.placeholder.pia_username}
        PIA_PASSWORD=${config.sops.placeholder.pia_password}
      '';
    };

    networking.networkmanager.ensureProfiles = {
      environmentFiles = [ config.sops.templates."pia-nm.env".path ];
      profiles = lib.mapAttrs (_: mkOpenVpnProfile) cfg.profiles;
    };
  };
}
