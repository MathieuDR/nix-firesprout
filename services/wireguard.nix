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
