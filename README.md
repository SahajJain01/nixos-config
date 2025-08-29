# nixos-config

## Bun Monorepo Deployer

This repo includes a NixOS module that discovers Bun apps in a monorepo and deploys them as systemd services behind Caddy with automatic HTTPS.

### Requirements

- Monorepo with apps under `apps/*`
- Each app contains a `bun-app.json` with at least:

```
{
  "name": "fixed-calendar",
  "prod": "bun run prod",
  "domain": "calendar.example.com"
}
```

Note: Ensure valid JSON (no trailing commas).

### Enable

Edit `configuration.nix` and enable the module (fill in your repo URL and ACME email):

```
services.bunMonorepo = {
  enable = true;
  repoUrl = "https://github.com/you/your-mono.git"; # REQUIRED
  ref = "main";                       # optional, default "main"
  appsDir = "apps";                   # optional, default "apps"
  basePort = 3000;                     # optional, sequential starting port
  caddyEmail = "admin@example.com";   # optional, for automatic HTTPS
  env = {                              # optional, extra env for all apps
    # EXAMPLE_KEY = "value";
  };
};
```

Then apply:

```
sudo nixos-rebuild switch
```

### How it works

- At evaluation, Nix pulls the repo and reads `apps/*/bun-app.json` to determine apps, domains, and the prod command.
- Each app gets a deterministic port starting at `basePort` and incrementing by 1.
- At runtime, systemd clones/updates the repo into `/var/lib/bun-monorepo/repo`, installs production dependencies with Bun, and runs the `prod` command with `PORT` set.
- Caddy is configured with one vhost per app and `reverse_proxy` to `127.0.0.1:<port>`; it will request certificates automatically if `caddyEmail` is set.

### Caveats

- Using `builtins.fetchGit` means rebuilds will pull from the branch (`ref`). Pin a `rev` if you want reproducibility.
- `bun install` runs in each app directory. Ensure the app can install in production without interactive steps.
- If you add or remove apps, rebuild to update services and Caddy vhosts.
