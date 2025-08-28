# nixos-config

## Quick Bun App Deploys

This config adds a reusable systemd template, Caddy reverse proxy, and two helper commands to rapidly deploy Bun apps from GitHub:

- `deploy-bun <name> <git-url> <branch> <port> <subdir> <start-cmd> [domain]`
- `remove-bun <name> [--purge]`

Examples:

```
# Basic: run on port 3000, repo root, start with `bun run start`
sudo deploy-bun blog https://github.com/you/blog.git main 3000 . 'bun run start'

# With a subdomain routed to the server (Caddy will obtain TLS):
sudo deploy-bun api https://github.com/you/api.git main 4000 . 'bun run start' api.example.com

# Remove and purge data
sudo remove-bun api --purge
```

Notes:

- Env/config lives in `/etc/bun-apps/<name>.env` (can include secrets and extra env).
- Source code is kept under `/var/lib/bun-apps/<name>/src`.
- Logs: `journalctl -u bun-app@<name> -f`.
- Caddy vhosts are dropped into `/etc/caddy/Caddyfile.d/<name>.caddy`.
- Optional: set `BUILD_CMD` in the env file to run a build during deploy (runs before start), e.g. `BUILD_CMD=bun run build`.

### Building with flakes

```
# On the server (aarch64 NixOS), from this repo:
sudo nixos-rebuild switch --flake .#oracle-arm
```

If your machine has a different host name or architecture, adjust `flake.nix` accordingly.

## Layout

- `flake.nix` – flake entry and `nixosConfigurations.oracle-arm`.
- `hosts/oracle-arm/default.nix` – main module for this host.
- `hosts/oracle-arm/hardware-configuration.nix` – generated hardware profile.
- `modules/bun-apps.nix` – reusable Bun/Caddy deploy module.
