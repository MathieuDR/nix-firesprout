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

  networking = {
    hostName = "${hostname}";

    interfaces.enp9s0 = {
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
    snapper.configs.storage = {
      SUBVOLUME = "/storage";

      # Create automatic snapshots every hour
      TIMELINE_CREATE = true;

      # Automatically delete old snapshots
      TIMELINE_CLEANUP = true;

      # How many snapshots to keep
      TIMELINE_LIMIT_HOURLY = 24;
      TIMELINE_LIMIT_DAILY = 7;
      TIMELINE_LIMIT_WEEKLY = 4;
      TIMELINE_LIMIT_MONTHLY = 3;
      TIMELINE_LIMIT_YEARLY = 0;
    };

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
    oomd = {
      enable = true;
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
