# Home server hardware upgrade — buying prompt

I want to replace the guts of my home server and need help choosing parts. Give me
2-3 concrete build options at different price/size/power points, each with a specific
part list, an estimated idle power draw at the wall, and the reasoning behind the
trade-offs. Ask me clarifying questions if a decision hinges on something you don't know.

## What it's for

It's a NixOS home server running containerized services (podman): paperless-ngx (+tika,
gotenberg, postgres, redis, celery), immich (photo library with ML: CLIP search + face
detection), Actual Budget, and Caddy as a reverse proxy. A separate Raspberry Pi handles
AdGuard/DNS, so that's not part of this box. I want to ADD media streaming (Jellyfin),
which means hardware video transcoding matters.

## Current machine (what I'm replacing and why)

- CPU: AMD Ryzen 7 1700 (first-gen Zen). Board: ASRock AB350 Pro4.
- It hard-freezes at idle every ~8-12h with nothing in the logs. This is the known
  first-gen Ryzen idle/low-current hang; the board's ACPI C-state firmware is buggy.
  I'm done fighting it and want a stable, modern, low-power replacement.

## Parts I'd like to REUSE if it's sensible (tell me when it isn't)

- RAM: 32 GB DDR4-3200 CL16 (4x 8 GB, G.Skill Ripjaws V).
- Storage: 1 TB NVMe (Kingston A2000, M.2), 1 TB SATA SSD (Crucial MX300, 2.5"),
  2x 4 TB 3.5" HDD (Seagate IronWolf NAS).
- Maybe the GPU: Gigabyte GTX 1080 Ti (11 GB, Pascal). Big and ~250 W.
- Maybe the PSU: Corsair RM650x (650 W ATX).

## Requirements / wishes, roughly in priority order

1. Rock-solid stability and low idle power draw (it runs 24/7; low power is ALWAYS nice).
2. Small form factor.
3. Runs the services above comfortably, and handles Jellyfin streaming including
   hardware transcoding (multiple 1080p or a 4K->1080p transcode).
4. Nice-to-have, NOT required: enough GPU for light local AI inference (LLMs via
   llama.cpp) and to accelerate immich ML. If this pushes cost/size/power up a lot,
   drop it.

## Trade-offs I already know about - please navigate these explicitly

- Reusing DDR4 rules out AM5 (DDR5 only). It points toward LGA1700 with a DDR4 board,
  or staying on AM4 (e.g. Ryzen 5000). Tell me if buying new DDR5 + a modern low-power
  platform is actually the better call despite "wasting" my DDR4.
- Small form factor vs. reusing 2x 3.5" HDDs and an ATX PSU and a 250 W triple-slot GPU
  are in direct conflict. Tell me what genuinely fits an SFF/ITX build vs. what forces a
  bigger case, and whether I should keep the HDDs external/in a NAS-style enclosure.
- For transcoding specifically, weigh an Intel iGPU with QuickSync (near-zero extra
  power, fits SFF) against keeping the 1080 Ti / a discrete GPU. Recommend whether the
  1080 Ti is worth keeping at all for my use, or better sold.

For each build option, cover: CPU + iGPU transcode capability, motherboard (with which
RAM path), what of my old parts it reuses, case + PSU that physically fit, idle power
estimate, and rough total cost for the new parts only. Assume I'm in Germany for parts
availability and pricing.
