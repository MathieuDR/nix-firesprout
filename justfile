# Define the default recipe to list available commands
default:
    @just --list

# Wipes nixos, and puts new config on it. Also wipes the know host lines (line 4)
wipe:
	sed -i '4d' ~/.ssh/known_hosts
	sed -i '4d' ~/.ssh/known_hosts
	nix run github:nix-community/nixos-anywhere -- --flake .#firesprout root@${SERVER_IP}

# Local Rebuild nixos, no wipy
rebuild-local:
	nixos-rebuild switch --flake .#firesprout

# Rebuilds nixos, doesn't wipe
rebuild:
	nixos-rebuild switch --flake .#firesprout --target-host root@${SERVER_IP}

rebuild-user:
	nixos-rebuild switch --flake .#firesprout --target-host ${SERVER_USERNAME}@${SERVER_IP} --use-remote-sudo

# Rebuilds nixos, doesn't wipe, with no cache
rebuild-no-cache:
	nixos-rebuild switch --flake .#firesprout --target-host root@${SERVER_IP} --option eval-cache false

# Rebuilds nixos, doesn't wipe, with a trace
rebuild-trace:
	nixos-rebuild switch --flake .#firesprout --target-host root@${SERVER_IP} --show-trace

# Rebuilds nixos, doesn't wipe, with no cache
rebuild-trace-no-cache:
	nixos-rebuild switch --flake .#firesprout --target-host root@${SERVER_IP} --option eval-cache false --show-trace

connect:
	ssh ${SERVER_USERNAME}@${SERVER_IP}

connect-root:
	ssh root@${SERVER_IP}

sync-calibre:
  rsync -avz --delete --exclude='*/data/' --chown=calibre-web:calibre-web --chmod=D2775,F664 "${LOCAL_CALIBRE}" "root@${SERVER_IP}:/var/lib/calibre-library/"
