# Plan: FoundryVTT via WireGuard tunnel from the Hetzner VPS

Goal: run **FoundryVTT on firesprout** (the box with RAM) but keep it reachable at the same
public URL, by tunneling from the Hetzner VPS (public IP, front door) to firesprout (behind
Vodafone CGNAT/DS-Lite, so it dials out). Frees the VPS RAM that forced the D&D-night pause dance.

## Facts

- VPS (nix-dock): public IP **5.75.252.210**, flake attr `.#nixos`, Caddy on 80/443 (HTTP-01 TLS,
  no DNS token). Foundry currently runs here: `services.foundryvtt` port **8412**, data
  `/var/lib/foundryvtt`, `hostName = "drakkenheim.deraedt.dev"`, `proxySSL/proxyPort=443`.
  `ddb-proxy` (port 9313) also here.
- firesprout: 32 GB RAM, behind CGNAT (dials out), flake `.#firesprout`.
- Public URL stays **drakkenheim.deraedt.dev** → VPS (no DNS change). Tunnel subnet **10.100.0.0/24**
  (VPS = 10.100.0.1, firesprout = 10.100.0.2). WG UDP port 51820.
- **ddb-proxy stays on the VPS** (stateless, tiny; no reason to port its custom package). Foundry
  reaches it at `ddb-proxy.deraedt.dev`.

## Architecture

```
players ──https──► drakkenheim.deraedt.dev (A → 5.75.252.210)
                        │  VPS Caddy (LE TLS) → reverse_proxy over WG
        10.100.0.1 (VPS) ◄──── 10.100.0.2 (firesprout dials out, keepalive)
                        │
                 firesprout: Foundry :8412
```

## Phase 1 — WireGuard tunnel (get it up + verified)  ← IN PROGRESS

Private keys generated on each box at `/etc/wireguard/wg0.key` (root 600, NOT in git);
`privateKeyFile` points at them. Only public keys go in the configs.

**firesprout `services/wireguard.nix`:**
```nix
{...}: {
  networking.wireguard.interfaces.wg0 = {
    ips = ["10.100.0.2/24"];
    privateKeyFile = "/etc/wireguard/wg0.key";
    peers = [{
      publicKey = "<VPS_PUBKEY>";
      allowedIPs = ["10.100.0.1/32"];
      endpoint = "5.75.252.210:51820";
      persistentKeepalive = 25;   # holds the CGNAT hole open
    }];
  };
}
```

**nix-dock `services/wireguard.nix`:**
```nix
{...}: {
  networking.firewall.allowedUDPPorts = [51820];
  networking.wireguard.interfaces.wg0 = {
    ips = ["10.100.0.1/24"];
    listenPort = 51820;
    privateKeyFile = "/etc/wireguard/wg0.key";
    peers = [{
      publicKey = "<FIRESPROUT_PUBKEY>";
      allowedIPs = ["10.100.0.2/32"];
      # no endpoint — firesprout dials in from behind CGNAT
    }];
  };
}
```

**Verify:** deploy both, then on firesprout `wg show` (latest handshake) and `ping 10.100.0.1`;
from the VPS `ping 10.100.0.2`.

## Phase 2 — Foundry on firesprout

- Add flake input `foundryvtt = github:cdata/nix-foundryvtt` (follows nixpkgs-unstable) + the module.
- `services/foundryvtt.nix`: same as the VPS (`hostName = "drakkenheim.deraedt.dev"`, `proxySSL`,
  `proxyPort = 443`, `port = 8412`, package `foundryvtt_14` v14.360, `nodejs_24`), but relax memory
  (`MemoryHigh = "6G"; MemoryMax = "8G"`).
- Firewall: `networking.firewall.interfaces.wg0.allowedTCPPorts = [8412]` — reachable ONLY via the tunnel.
- Add `/var/lib/foundryvtt` to restic backup paths.

## Phase 3 — Cutover

1. Stop Foundry on the VPS.
2. From firesprout, pull the data over SSH (firesprout → VPS is allowed):
   `rsync -aHAX root@5.75.252.210:/var/lib/foundryvtt/ /var/lib/foundryvtt/`
   `rsync -aHAX root@5.75.252.210:/home/<user>/foundry_assets/ /home/<user>/foundry_assets/`
   `chown -R foundryvtt:foundryvtt /var/lib/foundryvtt`   # uids differ per host (the immich trap)
3. Deploy Foundry on firesprout; confirm `ss -tlnp | grep 8412`.
4. On the VPS: remove `services.foundryvtt` + its systemd overlay + the `pauseDuringDnd` juggling;
   change the Caddy vhost:
   `services.caddy.virtualHosts.${domainUtils.domain "drakkenheim"}.extraConfig = ''` \
   `  reverse_proxy http://10.100.0.2:8412` \
   `  encode { zstd gzip minimum_length 1024 }` \
   `''`;
5. Test `https://drakkenheim.deraedt.dev` — now served from firesprout via the tunnel.

## Gotchas

- **Foundry is one license/instance** — stop it on the VPS before running it on firesprout.
- **uid mismatch** on `/var/lib/foundryvtt` after copy → chown (same trap immich hit).
- **Keepalive = 25** is mandatory for CGNAT (VPS can't reach back otherwise).
- Foundry stays **proxy-aware** so WebSockets/logins build correct URLs; Caddy proxies WS automatically.
- **Security:** Foundry is on the tunnel only (wg0 firewall), never the LAN or open net — only the VPS
  Caddy reaches it. Keep Foundry's admin access key on; optional `basic_auth` at the vhost.

## Status

- [x] Branch `foundry-tunnel`
- [ ] Phase 1: WireGuard configs written + deployed both sides, tunnel verified
- [ ] Phase 2: Foundry running on firesprout
- [ ] Phase 3: cutover (data moved, VPS Caddy → tunnel, VPS Foundry removed)
