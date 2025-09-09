NixOS configuration for hosting Fixed Calendar behind Caddy with Docker

- Domain: `calendar.sahajjain.com`
- Reverse proxy: Caddy (automatic HTTPS, HSTS, HTTP→HTTPS)
- App container: `ghcr.io/sahajjain01/fixed-calendar:latest`
- Network: default Docker bridge; app bound only to loopback

What this repo sets up
- `containers.nix`: Runs the calendar container and binds `127.0.0.1:3000:3000` so it is not exposed externally.
- `configuration.nix`: Enables Caddy and proxies `calendar.sahajjain.com` → `127.0.0.1:3000` with HSTS. Also enables Docker, SSH, and basic system settings.
- `firewall.nix`: Opens TCP ports `80` and `443` for the reverse proxy only.

Prerequisites
- DNS A/AAAA record for `calendar.sahajjain.com` points to this server.
- NixOS with flakes enabled (already enabled in `configuration.nix`).

Deploy / apply changes
1) Edit files as needed, then apply:
   - `sudo nixos-rebuild switch` (alias: `nswitch`)
2) Verify services:
   - `systemctl status docker-calendar`
   - `systemctl status caddy`
3) Quick checks:
   - `curl -fsS http://127.0.0.1:3000 | head -n1` (app locally)
   - `curl -I https://calendar.sahajjain.com` (HTTPS + proxy)

Customization
- Change domain: edit `configuration.nix` under `services.caddy.virtualHosts."calendar.sahajjain.com"`.
- Change app port: update `containers.nix` `ports = [ "127.0.0.1:3000:3000" ];` and the matching `reverse_proxy 127.0.0.1:3000` in `configuration.nix`.
- Pin image tag/digest: change `image = "ghcr.io/sahajjain01/fixed-calendar:latest";` in `containers.nix` (e.g., use an immutable digest).
- Optional ACME contact email for Caddy: set `services.caddy.email = "you@example.com";` in `configuration.nix`.

Security notes
- The container is reachable only on loopback (`127.0.0.1:3000`), not from the internet.
- Only ports 80/443 are open on the firewall; Caddy terminates TLS and forwards to the local app.
- HSTS is enabled for stronger HTTPS enforcement.

Files of interest
- `containers.nix`
- `configuration.nix`
- `firewall.nix`
- `flake.nix`

Troubleshooting
- If you see an error like “The option `virtualisation.oci-containers.containers.services.caddy` does not exist”, make sure the Caddy config lives at the top level in `configuration.nix` under `services.caddy`, not inside `containers.nix`.
- Show a detailed Nix trace: `nixos-rebuild switch --show-trace`.
- Inspect logs:
  - `journalctl -u caddy -e --no-pager`
  - `journalctl -u docker-calendar -e --no-pager`
