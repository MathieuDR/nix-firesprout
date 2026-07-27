{
  username,
  hostname,
  pkgs,
  inputs,
  ...
}: {
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    efiInstallAsRemovable = true;
    memtest86.enable = true;
  };

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_GB.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "nl_BE.UTF-8";
    LC_IDENTIFICATION = "nl_BE.UTF-8";
    LC_MEASUREMENT = "nl_BE.UTF-8";
    LC_MONETARY = "nl_BE.UTF-8";
    LC_NAME = "nl_BE.UTF-8";
    LC_NUMERIC = "nl_BE.UTF-8";
    LC_PAPER = "nl_BE.UTF-8";
    LC_TELEPHONE = "nl_BE.UTF-8";
    LC_TIME = "nl_BE.UTF-8";
  };

  console = {
    useXkbConfig = true;
  };

  # The new board's Realtek 2.5GbE enumerates under a different name than the old
  # enp9s0, which would drop the static IP (and SSH) on first boot. Pin it to a
  # stable name by MAC so 192.168.178.210 always lands on the LAN port.
  #
  systemd.network.links."10-lan0" = {
    matchConfig.MACAddress = "30:56:0f:a6:ad:e2";
    linkConfig.Name = "lan0";
  };

  networking = {
    hostName = "${hostname}";

    interfaces.lan0 = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = "192.168.178.210";
          prefixLength = 24;
        }
      ];
    };

    defaultGateway = "192.168.178.1";
    nameservers = ["192.168.178.1"];
  };

  imports = [
    ./services
  ];

  # Intel UHD 770 iGPU (replaces the sold GTX 1080 Ti). QuickSync for Jellyfin
  # transcoding; render node also available to immich for OpenVINO ML later.
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver # iHD VAAPI driver (Gen12)
      vpl-gpu-rt # oneVPL runtime for QSV
      # intel-compute-runtime  # add when wiring immich ML to OpenVINO
    ];
  };

  nixpkgs.config.allowUnfree = true;
  environment = {
    enableAllTerminfo = true;
    systemPackages = with pkgs; [
      curl
      git
      htop
      killall
      tree
      unzip
      zip
      vim
      wget
      rsync
      fd
      bat
      bottom
      dust
      procs
      sd
      yq
      fx
      lm_sensors
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  users.users = {
    root.openssh.authorizedKeys.keys = [
      (builtins.readFile ./secrets/id_rsa.pub)
    ];

    ${username} = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "docker"
        "podman"
      ];
      openssh.authorizedKeys.keys = [
        (builtins.readFile ./secrets/id_rsa.pub)
      ];
    };
  };

  home-manager.users.${username} = {
    imports = [
      ./home.nix
    ];
  };

  services = {
    # snapper.configs.storage = {
    #   SUBVOLUME = "/storage";
    #
    #   # Create automatic snapshots every hour
    #   TIMELINE_CREATE = true;
    #
    #   # Automatically delete old snapshots
    #   TIMELINE_CLEANUP = true;
    #
    #   # How many snapshots to keep
    #   TIMELINE_LIMIT_HOURLY = 24;
    #   TIMELINE_LIMIT_DAILY = 7;
    #   TIMELINE_LIMIT_WEEKLY = 4;
    #   TIMELINE_LIMIT_MONTHLY = 3;
    #   TIMELINE_LIMIT_YEARLY = 0;
    # };

    openssh = {
      enable = true;

      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "yes";
      };
    };

    journald.extraConfig = ''
      SystemMaxUse=300M
      SystemMaxFileSize=50M
      MaxRetentionSec=1week
      MaxFileSec=1day
      RuntimeMaxUse=100M
    '';
  };

  systemd = {
    # This actually causes freezes.
    oomd = {
      enable = false;
      enableRootSlice = true;
      enableUserSlices = true;
    };

    # Make system.slice protected (keeps critical system services alive)
    slices.system = {
      sliceConfig = {
        ManagedOOMMemoryPressure = "kill";
        ManagedOOMMemoryPressureLimit = "80%";
      };
    };
  };

  virtualisation.podman = {
    enable = true;
    autoPrune.enable = true;
  };

  system.stateVersion = "25.11";
  nix = {
    settings = {
      trusted-users = [username];

      accept-flake-config = true;
      auto-optimise-store = true;
    };

    registry = {
      nixpkgs = {
        flake = inputs.nixpkgs;
      };
    };

    nixPath = [
      "nixpkgs=${inputs.nixpkgs.outPath}"
    ];

    package = pkgs.nixVersions.stable;
    extraOptions = ''experimental-features = nix-command flakes'';

    gc = {
      automatic = true;
      options = "--delete-older-than 14d";
    };
  };
}
