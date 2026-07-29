# Firesprout Monitoring Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this task-by-task. Steps use `- [ ]` checkboxes.
> **No TDD:** this is NixOS config with no test framework. Each task's cycle is: write the module → `nix eval` (catches config errors) → **the user deploys** (`nixos-rebuild` from their Linux box) → functional verify over SSH → commit. The agent does NOT run `nixos-rebuild`.

**Goal:** Stand up the Tier-1 monitoring stack on firesprout — ntfy, smartd, a SMART history log, Beszel, Gatus, and zero-config systemd `OnFailure` crash alerts — all pushing to one ntfy sink.

**Architecture:** Six focused modules under `services/monitoring/`, imported via `services/monitoring/default.nix`. Everything runs on firesprout; alerts publish to a single local ntfy topic (`firesprout`); the phone subscribes. State lives on the NVMe. See `monitoring-design.md`.

**Tech Stack:** NixOS 25.11 modules (`services.ntfy-sh`, `services.smartd`, `services.beszel.{hub,agent}`, `services.gatus`), podman (existing), agenix, Caddy, `smartmontools`, `jq`.

## Global Constraints

- Branch `foundry-tunnel`; flake attr `.#firesprout`; NixOS **25.11**.
- **The user deploys** (their Linux `nixos-rebuild`); the agent only edits, `nix eval`s, and verifies over `ssh root@192.168.178.210`.
- All monitoring state on the **NVMe** under `/var/lib/*` — never on `/cold-storage`.
- Caddy vhost pattern (LAN-only `*.home.deraedt.dev`): `reverse_proxy http://127.0.0.1:<port>` + `encode { zstd gzip minimum_length 1024 }`.
- Secrets via **agenix**: add `.age` files under `secrets/`, register recipients in `secrets/secrets.nix` (host key `ssh_host_ed25519_key`), reference with `age.secrets."name".file`.
- ntfy: base URL `https://ntfy.home.deraedt.dev`, topic `firesprout`.
- Every long-running service gets `MemoryHigh`/`MemoryMax` caps.
- New modules import through `services/monitoring/default.nix`, which is added once to `services/default.nix`'s `imports`.
- Each task commit message: conventional, small, **no `Co-Authored-By`**.

## File Structure

- `services/monitoring/default.nix` — imports the six modules; defines the shared `ntfy-send` helper package and the `/var/lib/smart-history` tmpfiles rule.
- `services/monitoring/smart-history.nix` — timer + script writing `smartctl --json -x` to `.jsonl`.
- `services/monitoring/ntfy.nix` — ntfy server, Caddy vhost, auth provisioning, publish token file.
- `services/monitoring/smartd.nix` — smartd with self-test schedule + `-M exec` → `ntfy-send`.
- `services/monitoring/onfailure.nix` — `ntfy-failure@` template + zero-config attach to every `oci-containers` unit + key native units.
- `services/monitoring/beszel.nix` — Beszel hub + agent (smartmon, podman socket), Caddy vhost, secrets.
- `services/monitoring/gatus.nix` — Gatus with the endpoint list (grouped, one attrset each) + ntfy alerting, Caddy vhost.

---

### Task 1: SMART history log (easiest — no dependencies)

**Files:**
- Create: `services/monitoring/smart-history.nix`
- Create: `services/monitoring/default.nix`
- Modify: `services/default.nix` (add `./monitoring`)

**Interfaces:**
- Produces: `/var/lib/smart-history/smart.jsonl` (one JSON object per drive per run: `{ts, device, smart}`). Nothing consumes it programmatically yet; it's the historical record.

- [ ] **Step 1: Create `services/monitoring/default.nix`** (the umbrella + shared helper used by Tasks 3 & 4)

```nix
{ pkgs, ... }: let
  # Shared publisher: read the on-box ntfy token and POST a message.
  # Usage: ntfy-send "<title>" "<body>" [priority] [tags]
  ntfy-send = pkgs.writeShellApplication {
    name = "ntfy-send";
    runtimeInputs = [ pkgs.curl ];
    text = ''
      title="''${1:-firesprout}"; body="''${2:-}"; prio="''${3:-default}"; tags="''${4:-}"
      tok="$(cat /var/lib/ntfy-sh/publish-token 2>/dev/null || true)"
      curl -fsS --max-time 10 --retry 1 \
        ${"$"}{tok:+-H "Authorization: Bearer $tok"} \
        -H "Title: $title" -H "Priority: $prio" ${"$"}{tags:+-H "Tags: $tags"} \
        -d "$body" "http://127.0.0.1:2586/firesprout" >/dev/null
    '';
  };
in {
  imports = [
    ./smart-history.nix
    ./ntfy.nix
    ./smartd.nix
    ./onfailure.nix
    ./beszel.nix
    ./gatus.nix
  ];

  environment.systemPackages = [ ntfy-send ];
  systemd.tmpfiles.rules = [ "d /var/lib/smart-history 0750 root root -" ];
}
```

- [ ] **Step 2: Create `services/monitoring/smart-history.nix`**

```nix
{ pkgs, ... }: let
  devices = [ "/dev/nvme0" "/dev/sda" "/dev/sdb" ];
  snapshot = pkgs.writeShellApplication {
    name = "smart-history-snapshot";
    runtimeInputs = [ pkgs.smartmontools pkgs.jq pkgs.coreutils ];
    text = ''
      ts="$(date -Iseconds)"
      out=/var/lib/smart-history/smart.jsonl
      for d in ${toString devices}; do
        # -x = attributes + error log + self-test log; --json for machine-readable
        smartctl --json=c -x "$d" \
          | jq -c --arg ts "$ts" --arg dev "$d" '{ts:$ts, device:$dev, smart:.}' \
          >> "$out" || echo "{\"ts\":\"$ts\",\"device\":\"$d\",\"error\":\"smartctl failed\"}" >> "$out"
      done
    '';
  };
in {
  systemd.services.smart-history = {
    description = "Append a smartctl --json snapshot to the SMART history log";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${snapshot}/bin/smart-history-snapshot";
    };
  };
  systemd.timers.smart-history = {
    description = "Weekly SMART history snapshot";
    wantedBy = [ "timers.target" ];
    timerConfig = { OnCalendar = "weekly"; Persistent = true; };
  };
}
```

- [ ] **Step 3: Wire the umbrella into `services/default.nix`** — add `./monitoring` to the `imports` list.

- [ ] **Step 4: Eval** — `nix eval .#nixosConfigurations.firesprout.config.system.build.toplevel.drvPath` → resolves (no error). Fix any eval error before proceeding.

- [ ] **Step 5: User deploys**, then verify:

```bash
ssh root@192.168.178.210 'systemctl start smart-history && jq . /var/lib/smart-history/smart.jsonl | head -40'
```
Expected: one JSON object per drive, each containing `ata_smart_self_test_log` (or `nvme_self_test_log`) and the attribute table.

- [ ] **Step 6: Commit** — `feat(monitoring): weekly smartctl --json SMART history log`

---

### Task 2: ntfy (the alert sink)

**Files:**
- Create: `services/monitoring/ntfy.nix`
- Create: `secrets/ntfy/publish-password.age`; Modify: `secrets/secrets.nix`
- Modify: `services/caddy.nix` (or add the vhost inside `ntfy.nix` — follow the existing per-service vhost pattern; define it in `ntfy.nix`)

**Interfaces:**
- Produces: ntfy on `127.0.0.1:2586`; public `https://ntfy.home.deraedt.dev`; topic `firesprout`; a runtime token at `/var/lib/ntfy-sh/publish-token` (read by `ntfy-send`) and `/var/lib/ntfy-sh/publish-token.env` (`NTFY_TOKEN=...`, read by Gatus in Task 6). ntfy user `alerts` (password from agenix) for the phone.

- [ ] **Step 1: Create the agenix secret** (password *you* choose for the `alerts` user):

```bash
cd /Users/mathieu.deraedt/development/sources/nix-firesprout
# add to secrets/secrets.nix: "ntfy/publish-password.age".publicKeys = [ <firesprout host key> ];
agenix -e secrets/ntfy/publish-password.age   # type a strong password, save
```

- [ ] **Step 2: Create `services/monitoring/ntfy.nix`**

```nix
{ self, config, pkgs, ... }: {
  age.secrets."ntfy/publish-password".file = "${self}/secrets/ntfy/publish-password.age";

  services.ntfy-sh = {
    enable = true;
    settings = {
      base-url = "https://ntfy.home.deraedt.dev";
      listen-http = "127.0.0.1:2586";
      behind-proxy = true;
      auth-file = "/var/lib/ntfy-sh/user.db";
      auth-default-access = "deny-all";
    };
  };

  # Idempotent auth provisioning: create the `alerts` user + grant rw on the
  # topic + mint one access token that senders read at runtime.
  systemd.services.ntfy-provision = {
    description = "Provision ntfy user + publish token";
    after = [ "ntfy-sh.service" ];
    requires = [ "ntfy-sh.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
    path = [ config.services.ntfy-sh.package ];  # provides the `ntfy` CLI
    script = ''
      export NTFY_PASSWORD="$(cat ${config.age.secrets."ntfy/publish-password".path})"
      if ! ntfy user list 2>/dev/null | grep -q '^user alerts'; then
        ntfy user add alerts
      fi
      ntfy access alerts firesprout rw || true
      if [ ! -s /var/lib/ntfy-sh/publish-token ]; then
        tok="$(ntfy token add --expires=never alerts | grep -oE 'tk_[A-Za-z0-9]+' | head -1)"
        umask 077
        printf '%s' "$tok" > /var/lib/ntfy-sh/publish-token
        printf 'NTFY_TOKEN=%s\n' "$tok" > /var/lib/ntfy-sh/publish-token.env
      fi
    '';
  };

  systemd.services.ntfy-sh.serviceConfig = { MemoryHigh = "48M"; MemoryMax = "64M"; };

  services.caddy.virtualHosts."ntfy.home.deraedt.dev".extraConfig = ''
    reverse_proxy http://127.0.0.1:2586
    encode { zstd gzip minimum_length 1024 }
  '';
}
```

> **On-box verification note for this task:** the exact `ntfy user`/`ntfy token` CLI flags (non-interactive password via `NTFY_PASSWORD`, token grep pattern) are the one fiddly part — confirm against `ntfy user --help` / `ntfy token --help` on the box and adjust the `script` if needed. This is the trickiest task; get it solid before moving on.

- [ ] **Step 3: Eval** → resolves.

- [ ] **Step 4: User deploys**, then verify publish + subscribe:

```bash
ssh root@192.168.178.210 'cat /var/lib/ntfy-sh/publish-token >/dev/null && ntfy-send "test" "hello from firesprout" && echo SENT'
```
Then install the **ntfy Android app**, add server `https://ntfy.home.deraedt.dev`, log in as `alerts`, subscribe to `firesprout`, and confirm the test message arrives (on home WiFi).

- [ ] **Step 5: Commit** — `feat(monitoring): self-hosted ntfy alert sink with token auth`

---

### Task 3: smartd (disk health → ntfy)

**Files:**
- Create: `services/monitoring/smartd.nix`

**Interfaces:**
- Consumes: `ntfy-send` (Task 1), the running ntfy (Task 2).
- Produces: scheduled short/long self-tests (their results land in Task 1's log); email-style alerts routed through `ntfy-send`.

- [ ] **Step 1: Create `services/monitoring/smartd.nix`**

```nix
{ pkgs, ... }: let
  # smartd calls this with the alert details in env vars (SMARTD_*).
  notify = pkgs.writeShellApplication {
    name = "smartd-ntfy";
    runtimeInputs = [ ];
    text = ''
      ntfy-send "Disk alert: ''${SMARTD_DEVICE:-?}" \
        "''${SMARTD_MESSAGE:-SMART event} (fail=''${SMARTD_FAILTYPE:-?})" \
        "high" "floppy_disk,warning"
    '';
  };
in {
  services.smartd = {
    enable = true;
    autodetect = false;
    notifications.test = true;   # sends one ntfy on (re)start to prove the path
    defaults.monitored = "-a -o on -S on -s (S/../.././02|L/../01/./03) -W 5,45,55 -m <nomailer> -M exec ${notify}/bin/smartd-ntfy";
    devices = [
      { device = "/dev/nvme0"; }
      { device = "/dev/sda"; }
      { device = "/dev/sdb"; }
    ];
  };
  # smartd itself is tiny; no cap needed. The notify path uses the system ntfy-send.
}
```

Notes baked in: `-s (S/../.././02|L/../01/./03)` = short test daily 02:00, long test on the 1st monthly 03:00; `-W 5,45,55` = temp change/info/crit; `-M exec` routes every alert through `smartd-ntfy`; `-m <nomailer>` disables mail.

- [ ] **Step 2: Eval** → resolves.

- [ ] **Step 3: User deploys**, then verify:

```bash
ssh root@192.168.178.210 'systemctl restart smartd && journalctl -u smartd -n 20 --no-pager'
```
Expected: smartd starts, and the `notifications.test`/`-M test` fires one ntfy ("test") to your phone. Optionally `smartctl -t short /dev/sda` and check the result appears in next week's history log (or run Task 1's snapshot now).

- [ ] **Step 4: Commit** — `feat(monitoring): smartd self-tests + alerts via ntfy`

---

### Task 4: systemd `OnFailure` → ntfy (zero-config over oci-containers)

**Files:**
- Create: `services/monitoring/onfailure.nix`

**Interfaces:**
- Consumes: `ntfy-send` (Task 1).
- Produces: a `ntfy-failure@.service` template; auto-attaches `OnFailure` to every `virtualisation.oci-containers.containers` unit + a fixed list of key native units.

- [ ] **Step 1: Create `services/monitoring/onfailure.nix`** (mirrors `container-update.nix`'s `mapAttrs` over `oci-containers`)

```nix
{ config, lib, pkgs, ... }: let
  containerUnits =
    map (name: "podman-${name}.service")
      (lib.attrNames config.virtualisation.oci-containers.containers);
  # Native (non-podman) units worth watching:
  nativeUnits = [
    "immich-server.service" "immich-machine-learning.service"
    "paperless-web.service" "paperless-scheduler.service"
    "paperless-consumer.service" "paperless-task-queue.service"
    "caddy.service"
  ];
  watched = containerUnits ++ nativeUnits;
in {
  # Template: %i is the failed unit name. Fires once per failed unit
  # (a cascade sends a few — acceptable and informative).
  systemd.services."ntfy-failure@" = {
    description = "Notify ntfy that %i failed";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "ntfy-failure" ''
        unit="$1"
        tail="$(journalctl -u "$unit" -n 15 --no-pager 2>/dev/null || true)"
        ntfy-send "Service failed: $unit" "$tail" "high" "rotating_light"
      '' + " %i";
    };
  };

  # Zero-config attach: any current/future oci-container is covered automatically.
  systemd.services = lib.genAttrs watched (_: {
    onFailure = [ "ntfy-failure@%n.service" ];
  });
}
```

> Note: `lib.genAttrs watched (_: {...})` merges an `onFailure` into each named unit. Because `containerUnits` is derived from `oci-containers`, adding a container later needs no edit here.

- [ ] **Step 2: Eval** → resolves. (If a listed native unit doesn't exist in the config, drop it from `nativeUnits`.)

- [ ] **Step 3: User deploys**, then verify with a low-stakes unit:

```bash
ssh root@192.168.178.210 'systemctl kill -s SIGKILL podman-mealie 2>/dev/null; sleep 3; systemctl status "ntfy-failure@podman-mealie.service" --no-pager | head'
```
Expected: an ntfy "Service failed: podman-mealie.service" arrives on the phone. (systemd restarts mealie per its Restart policy.)

- [ ] **Step 4: Commit** — `feat(monitoring): zero-config OnFailure crash alerts to ntfy`

---

### Task 5: Beszel (box + container health)

**Files:**
- Create: `services/monitoring/beszel.nix`
- Create: `secrets/beszel/agent-env.age` (holds `KEY=` and `TOKEN=`); Modify: `secrets/secrets.nix`

**Interfaces:**
- Consumes: ntfy (Task 2) — configured in Beszel's web UI.
- Produces: hub UI at `https://metrics.home.deraedt.dev`; agent reporting host + podman container + SMART stats.

- [ ] **Step 1: Enable the rootful podman socket** (needed for container stats) — add to `beszel.nix`:

```nix
virtualisation.podman.dockerSocket.enable = true;  # exposes /run/podman/podman.sock
```

- [ ] **Step 2: Create `services/monitoring/beszel.nix`**

```nix
{ self, config, ... }: {
  virtualisation.podman.dockerSocket.enable = true;

  services.beszel.hub = {
    enable = true;
    host = "127.0.0.1";
    port = 8090;
  };

  age.secrets."beszel/agent-env".file = "${self}/secrets/beszel/agent-env.age";

  services.beszel.agent = {
    enable = true;
    environmentFile = config.age.secrets."beszel/agent-env".path;  # KEY=, TOKEN=
    environment = {
      HUB_URL = "http://127.0.0.1:8090";
      DISABLE_SSH = "true";               # WebSocket mode
      DOCKER_HOST = "unix:///run/podman/podman.sock";
      SERVICE_PATTERNS = "podman-*,beszel*,immich-*,paperless-*";
    };
    smartmon = {
      enable = true;
      deviceAllow = [ "/dev/nvme0" "/dev/sda" "/dev/sdb" ];
    };
  };

  systemd.services.beszel-hub.serviceConfig = { MemoryHigh = "96M"; MemoryMax = "128M"; };
  systemd.services.beszel-agent.serviceConfig = { MemoryHigh = "48M"; MemoryMax = "64M"; };

  services.caddy.virtualHosts."metrics.home.deraedt.dev".extraConfig = ''
    reverse_proxy http://127.0.0.1:8090
    encode { zstd gzip minimum_length 1024 }
  '';
}
```

> **On-box resolution for this task (the flagged risk):** confirm the exact `services.beszel.agent` option names against the 25.11 module (`nixos-option services.beszel.agent` or the module source). Two things to verify: (a) the DynamicUser agent can actually read `/run/podman/podman.sock` — if permission-denied, either add the agent user to the socket group or, per the design's fallback, **drop `DOCKER_HOST` and skip container stats** (host metrics + SMART still work). (b) The hub↔agent registration (`KEY`/`TOKEN`): you may need to create the system in the hub UI first to obtain the `TOKEN`, then put `KEY` (hub's public key) + `TOKEN` into the agenix env file. Document the one-time UI step.

- [ ] **Step 3: Eval** → resolves.

- [ ] **Step 4: User deploys**, then in the Beszel UI (`https://metrics.home.deraedt.dev`): create the admin user, register the firesprout system (gets it green), and set **Settings → Notifications** ntfy URL: `ntfy://:<token>@ntfy.home.deraedt.dev/firesprout` (token from `/var/lib/ntfy-sh/publish-token`). Enable Status + CPU + Memory + Disk + Temperature alerts on the system. Verify:

```bash
ssh root@192.168.178.210 'systemctl status beszel-hub beszel-agent --no-pager | grep Active'
```
Expected: both active; dashboard shows CPU temp, RAM, disks (with SMART), and podman containers. Trip a low temperature threshold to confirm an ntfy fires.

- [ ] **Step 5: Commit** — `feat(monitoring): Beszel hub + agent (host, container, SMART)`

---

### Task 6: Gatus (endpoint up/down → ntfy)

**Files:**
- Create: `services/monitoring/gatus.nix`

**Interfaces:**
- Consumes: ntfy token env file `/var/lib/ntfy-sh/publish-token.env` (Task 2).
- Produces: status page at `https://status.home.deraedt.dev`; per-endpoint ntfy alerts.

- [ ] **Step 1: Create `services/monitoring/gatus.nix`** (endpoints grouped, one attrset each — delete a block to cull)

```nix
{ config, ... }: let
  ntfyAlert = [ { type = "ntfy"; failure-threshold = 3; success-threshold = 2; send-on-resolved = true; } ];
  ep = name: url: group: {
    inherit name group;
    inherit url;
    interval = "60s";
    conditions = [ "[STATUS] == 200" "[RESPONSE_TIME] < 3000" ];
    alerts = ntfyAlert;
  };
in {
  # Gatus reads ${NTFY_TOKEN} from this env file at runtime.
  systemd.services.gatus.serviceConfig = {
    EnvironmentFile = "/var/lib/ntfy-sh/publish-token.env";
    MemoryHigh = "48M"; MemoryMax = "64M";
  };

  services.gatus = {
    enable = true;
    settings = {
      web.port = 8095;
      alerting.ntfy = {
        url = "http://127.0.0.1:2586";
        topic = "firesprout";
        token = "\${NTFY_TOKEN}";
        priority = 4;
      };
      endpoints = [
        # --- home (firesprout) ---
        (ep "immich"   "https://pics.home.deraedt.dev/api/server/ping" "home")
        (ep "paperless" "https://docs.home.deraedt.dev" "home")
        (ep "actual"   "https://actual.home.deraedt.dev" "home")
        (ep "mealie"   "https://recipes.home.deraedt.dev/api/app/about" "home")
        (ep "ntfy"     "https://ntfy.home.deraedt.dev/v1/health" "home")
        (ep "beszel"   "https://metrics.home.deraedt.dev" "home")
        # --- public ---
        (ep "website"  "https://mathieu.deraedt.dev" "public")
        (ep "foundry"  "https://drakkenheim.deraedt.dev" "public")
        # --- VPS public (cull freely; confirm exact hosts from nix-dock Caddy) ---
        (ep "glance"    "https://glance.deraedt.dev" "vps")
        (ep "garden"    "https://garden.deraedt.dev" "vps")
        (ep "ghostfolio" "https://invest.deraedt.dev" "vps")
        (ep "commafeed" "https://feed.deraedt.dev" "vps")
        (ep "readdeck"  "https://readlater.deraedt.dev" "vps")
        (ep "shlink"    "https://l.deraedt.dev" "vps")
        (ep "goatcounter" "https://insights.deraedt.dev" "vps")
        (ep "ddb-proxy" "https://ddb-proxy.deraedt.dev" "vps")
      ];
    };
  };

  services.caddy.virtualHosts."status.home.deraedt.dev".extraConfig = ''
    reverse_proxy http://127.0.0.1:8095
    encode { zstd gzip minimum_length 1024 }
  '';
}
```

> Resolve at implementation: confirm each VPS host resolves publicly (drop any that 404/redirect), and pick health-friendly paths where a bare `/` returns non-200 (immich/mealie already use API paths above). Confirm `services.gatus` settings schema against the 25.11 module (option is `settings`).

- [ ] **Step 2: Eval** → resolves.

- [ ] **Step 3: User deploys**, then verify:

```bash
ssh root@192.168.178.210 'systemctl status gatus --no-pager | grep Active'
```
Open `https://status.home.deraedt.dev` — all endpoints green. Stop one service (e.g. `systemctl stop podman-actual`) and confirm, after ~3 checks, an ntfy alert fires; restart it and confirm the resolved notification.

- [ ] **Step 4: Commit** — `feat(monitoring): Gatus status page + per-endpoint ntfy alerts`

---

### Task 7: Wrap-up — measure the cost

**Files:** none (verification + a note).

- [ ] **Step 1: Measure actual footprint** after everything is running:

```bash
ssh root@192.168.178.210 'for u in ntfy-sh beszel-hub beszel-agent gatus smartd; do printf "%-14s " "$u"; systemctl show -p MemoryCurrent "$u" | cut -d= -f2 | numfmt --to=iec; done'
```
Also read Beszel's own per-service/per-container view for CPU. Confirm each is under its `MemoryMax`.

- [ ] **Step 2: Record the numbers** in `monitoring-design.md` under a new "Measured footprint" line, and adjust caps if any service is close to its ceiling.

- [ ] **Step 3: Commit** — `docs: record measured monitoring footprint`

---

## Self-Review

- **Spec coverage:** ntfy ✓(T2) · smartd ✓(T3) · smart-history/JSON+self-tests ✓(T1) · Beszel host+container+SMART ✓(T5) · Gatus all-endpoints+cull ✓(T6) · OnFailure zero-config ✓(T4) · hot-storage `/var/lib` ✓(all) · secrets/agenix ✓(T2,T5) · resource caps+measurement ✓(all + T7) · subdomains ntfy/status/metrics.home ✓. Scrutiny/Netdata correctly absent.
- **Placeholders:** the `<...>` markers left are genuine per-box values (chosen password, generated token, host-key recipient) or explicit on-box option-name verifications (ntfy CLI flags, `services.beszel.agent`/`services.gatus` schema) — not logic gaps.
- **Type/name consistency:** `ntfy-send` (T1) is consumed by T3 & T4; `/var/lib/ntfy-sh/publish-token` (T2) → `ntfy-send`; `publish-token.env`/`NTFY_TOKEN` (T2) → Gatus (T6); topic `firesprout` and port `2586` used consistently.
