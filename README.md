# Secrets

We have 2 different type of *sensitive* information.

1. Secrets
2. PII

The secrets are encrypted through [agenix](agenix) whilst the PII is encrypted on git using [git-agecrypt](git-agecrypt).

The main difference is that agenix encrypts these secrets (tokens, passwords etc) and puts these in the `/nix/store` of the server. During the activation these will be decrypted.

The git-agecrypt decrypts this on our local machine and have these secrets available during evaluation and thus will end up in the `/nix/store` directory.

It is important that we make sure that no actual passwords or secrets ends up in [PII.json](./PII.json).

## How to create secrets

**Creating the secret**
Edit a secret `agenix -e 'name'`, example: `agenix -e restic/password.age`
*Note:* To specify the SSH key to use, use the `-i` argument, to specify the **identity**. `agenix -e restic/password.age -i ~/.shh/id_rsa`.

Add them to `secrets/secrets.nix` and add the public key of the used private key.

**Using the secret in the nix configuration**

In the root add the following values
```
age.secrets = {
    "name".file = <path_to_age_file>;
};
```

Which then can be used somewhere else with the following line `config.age.secrets."name".path;`

## How to add a PII file
Follow the [git-agecrypt](git-agecrypt) git instructions.

## Current PII information
If you want to use my configuration, and want to recreate the `PII.json` file. These are the keys.

```
caddyEmail
domain
email
git
git.userEmail
glance
glance.linear
host
location
location.city
location.country
location.lat
location.long
user
```

Created with the following command `jq -r 'paths | join(".")' file.json | sort | uniq`.
## Notes
Finding the public key: `ssh-keyscan <IP>`

## Current issues

### Hardware
CPU: AMD Ryzen 7 1700 3 GHz 8-Core Processor 
Motherboard: ASRock AB350 Pro4 ATX AM4 Motherboard 
Memory: 2x G.Skill Ripjaws V 16 GB (2 x 8 GB) DDR4-3200 CL16 Memory  ($119.99 @ Amazon)  (total of 32GB, 4 slots)
Storage: Kingston A2000 1 TB M.2-2280 PCIe 3.0 X4 NVME Solid State Drive 
Storage: Crucial MX300 1.05 TB 2.5" Solid State Drive 
Storage: 2x Seagate IronWolf NAS 4 TB 3.5" 5400 RPM Internal Hard Drive
Video Card: Gigabyte GAMING GeForce GTX 1080 Ti 11 GB Video Card 
Case: Corsair Crystal 570X RGB ATX Mid Tower Case 
Power Supply: Corsair RM650x (2018) 650 W 80+ Gold Certified Fully Modular ATX Power Supply

BIOS is updated to the latest version that still supports my old CPU

## Issue

The PC/Server is turned on, and it just 'freezes'/'dies' without logging anything in the kernel or journalctl. I need to power it off with the actual button and nothing shows in any logs that I've looked (dmesg, journalctl, etc). No OOM, no nothing.
I've tried turning disconnecting the NEW NAS drives, as I thought an issue might be there, but it wasn't.

Before turning this into a server, it was running quite smoothly as a daily driver using NIX and Hyprland. There were sometimes crashes but nothing as frequent as this.
When I turn it on, it usually crashes/freezes around the ~ 8 to 12 hour mark.

[age]: https://github.com/FiloSottile/age
[agenix]: https://github.com/ryantm/agenix
[git-agecrypt]: https://github.com/vlaci/git-agecrypt
