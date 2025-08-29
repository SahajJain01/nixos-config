# nixos-config

## Monorepo Auto-Deploy (recommended)

This repo includes a NixOS module that auto-deploys multiple Bun apps from a single monorepo. It:

- Scans your monorepo for `apps/*/bun-app.json`
- Builds and runs each app via systemd (`bun-app@<name>`) under the `bunapps` user
- Generates per-app Caddy vhosts when a `domain` is provided
- Supports an optional webhook to trigger syncs on push

### 1) Point the module at your monorepo

Edit `hosts/nixos/services/bun-monorepo.nix` and set:

- `services.bunMonorepo.repoUrl`: Git URL of your monorepo
- `branch`: branch to deploy (default `main`)
- `appsDir`: directory to scan (default `apps`)
- `portBase` / `portRange`: auto-port allocation window
- `webhook.domain`: optional domain to expose a sync webhook

### 2) Add `bun-app.json` in each app folder

Create `apps/<app>/bun-app.json` in your monorepo. Example (auto-assigned port):

```json
{
  "name": "myapp",
  "start": "bun run start",
  "build": "bun run build",
  "domain": "myapp.example.com",
  "branch": "main"
}
```

Fields:

- `name`: required, used for the systemd instance and Caddy file
- `start`: optional (default `bun run start`)
- `build`: optional build command run before start
- `port`: optional; if omitted a stable port is chosen from a hash and checked for collisions
- `domain`: optional; if set, Caddy proxies it to the app and manages TLS
- `branch`: optional; overrides the global `branch` for this app

### 3) Rebuild the host and run a sync

```
sudo nixos-rebuild switch --flake .#nixos
sudo systemctl start bun-monorepo-sync.service
```

Check logs:

```
journalctl -u bun-monorepo-sync -e -n 100 -f
journalctl -u bun-app@myapp -e -n 100 -f
```

Point your app domains (e.g., `myapp.example.com`) at the server's IP; Caddy will obtain TLS automatically.

### 4) Optional: Git webhook

The webhook listens locally and can be exposed via Caddy when `services.bunMonorepo.webhook.domain` is set. Configure a secret token at `/etc/bun-apps/webhook-secret` on the server, then:

- URL: `https://<webhook-domain>/sync`
- Method: `POST`
- Auth: header `x-webhook-token: <your-token>` (or `?token=...` query)

On receipt, it triggers `bun-monorepo-sync.service`.

---

## Legacy one-off deploy (manual)

If you prefer manual, single-repo deploys, adapt the `modules/bun-apps.nix` systemd template (`bun-app@`) by writing `/etc/bun-apps/<name>.env` with:

```
REPO=...      # git URL
BRANCH=main   # branch to deploy
PORT=3000     # port to bind
SUBDIR=.      # repo subdirectory
START_CMD='bun run start'
BUILD_CMD='bun run build'  # optional
```

Then start: `sudo systemctl start bun-app@<name>` and add a Caddyfile snippet under `/etc/caddy/Caddyfile.d/<name>.caddy` to route a domain.

### Building with flakes

```
# On the server (ensure architecture matches flake.nix), from this repo:
sudo nixos-rebuild switch --flake .#nixos
```

If your machine has a different host name or architecture, adjust `flake.nix` accordingly (e.g., switch `system` to `x86_64-linux`).

## Layout (modular)

- `flake.nix` - flake entry and `nixosConfigurations.nixos`.
- `modules/bun-apps.nix` - reusable Bun/Caddy deploy module.
- Host `nixos/` (modular):
  - `hosts/nixos/default.nix` - imports all host modules
  - `hosts/nixos/hardware-configuration.nix` - generated hardware profile
  - `hosts/nixos/networking.nix` - hostname + firewall
  - `hosts/nixos/ssh.nix` - SSH and authorized keys
  - `hosts/nixos/locale.nix` - timezone and locale
  - `hosts/nixos/boot.nix` - bootloader settings
  - `hosts/nixos/nix.nix` - Nix features/settings
  - `hosts/nixos/services/bun-monorepo.nix` - monorepo deploy service config

