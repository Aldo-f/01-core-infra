# Neo-Brutalist Homepage Role

Deploys a static neo-brutalist homepage with server metrics to `aldof.duckdns.org`.

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `site_name` | `06-apps-neo-brutalist-home` | Application identifier |
| `site_domain` | `aldof.duckdns.org` | Target domain |
| `site_root` | `/var/www/06-apps-neo-brutalist-home` | Web root directory |
| `metrics_script` | `/opt/06-apps-neo-brutalist-home/collect-metrics.sh` | Metrics collection script |
| `log_dir` | `/var/log/06-apps-neo-brutalist-home` | Log directory |
| `traefik_config_dir` | `/etc/traefik/dynamic` | Traefik dynamic config dir |

## Usage

Add to `ansible/playbooks/site.yml`:

```yaml
- name: Deploy Neo-Brutalist Homepage
  hosts: localhost
  roles:
    - neo-brutalist-home
```

## Files

| File | Purpose |
|------|---------|
| `tasks/main.yml` | Role tasks |
| `handlers/main.yml` | Nginx/Traefik reload handlers |
| `templates/index.html.j2` | Homepage HTML template |
| `templates/style.css` | Neo-brutalist CSS |
| `templates/collect-metrics.sh.j2` | Metrics collection script |
| `templates/neo-brutalist-home-metrics.service.j2` | systemd service |
| `templates/neo-brutalist-home-metrics.timer.j2` | systemd timer (60s) |
| `templates/nginx.conf.j2` | Nginx site config |
| `templates/traefik.toml.j2` | Traefik router config |
| `defaults/main.yml` | Default variables |
