# WireGuard tunnel to the Hetzner VPS (nix-dock, 5.75.252.210).
# firesprout is behind Vodafone CGNAT, so it dials OUT and holds the NAT hole open with a
# keepalive; the VPS reaches back over the tunnel. Private key lives at /etc/wireguard/wg0.key
# (generated on this box, root 600, never in git). See foundry-tunnel-plan.md.
{...}: {
  networking.wireguard.interfaces.wg0 = {
    ips = ["10.100.0.2/24"];
    privateKeyFile = "/etc/wireguard/wg0.key";
    peers = [
      {
        # Hetzner VPS (nix-dock)
        publicKey = "NVDgB1XSjn6YQX5Ipz/bLRNEAbdyG6t95b1zjADHOQc=";
        allowedIPs = ["10.100.0.1/32"];
        endpoint = "5.75.252.210:51820";
        persistentKeepalive = 25;
      }
    ];
  };
}
