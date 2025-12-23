{
  pkgs,
  username,
  nix-index-database,
  inputs,
  PII,
  ...
}: let
  unstable-packages = with pkgs.unstable; [
  ];

  stable-packages = with pkgs; [
    mosh
    httpie
    hurl
  ];
in {
  imports = [
    nix-index-database.homeModules.nix-index
  ];

  home.stateVersion = "25.11";

  home = {
    username = "${username}";
    homeDirectory = "/home/${username}";

    sessionVariables.EDITOR = "nvim";
  };

  home.packages =
    stable-packages
    ++ unstable-packages
    ++ [
      (inputs.yvim.packages.x86_64-linux.default)
    ];

  programs = {
    home-manager.enable = true;
    nix-index.enable = true;
    nix-index-database.comma.enable = true;

    fzf.enable = true;
    broot.enable = true;
    gh.enable = true;
    jq.enable = true;
    ripgrep.enable = true;

    zoxide = {
      enable = true;
      options = [
        "--cmd cd"
      ];
      enableBashIntegration = true;
    };

    lsd = {
      enable = true;
      enableBashIntegration = true;
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    oh-my-posh = {
      enable = true;
      enableBashIntegration = true;
      settings = builtins.fromJSON (builtins.readFile ./dotfiles/.ysomic.omp.json);
    };

    git = {
      enable = true;
      package = pkgs.unstable.git;
      settings = {
        user = {
          email = PII.git.userEmail;
          name = "MathieuDR";
        };
        push = {
          default = "current";
          autoSetupRemote = true;
        };
        merge = {
          conflictstyle = "diff3";
        };
        diff = {
          colorMoved = "default";
        };
      };
    };

    delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        line-numbers = true;
        side-by-side = true;
        navigate = true;
      };
    };

    bash = {
      enable = true;
      historySize = 2500;
    };
  };
}
