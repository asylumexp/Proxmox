<div align="center">
  <a href="#">
    <img src="https://raw.githubusercontent.com/asylumexp/Proxmox/main/misc/images/logo.png" height="100px" />
 </a>
</div>
<h1 align="center">Proxmox arm64 Install Scripts</h1>
<h3 align="center">an unofficial port of tteck's Helper-Scripts to arm64!</h3>

<p align="center">
  <a href="https://pimox-scripts.com">Website</a> | 
  <a href="https://github.com/asylumexp/Proxmox/blob/main/.github/CONTRIBUTING.md">Contribute</a> |
  <a href="https://github.com/asylumexp/Proxmox/blob/main/USER_SUBMITTED_GUIDES.md">Guides</a> |
  <a href="https://github.com/asylumexp/Proxmox/blob/main/CHANGELOG.md">Changelog</a> |
  <a href="https://ko-fi.com/D1D7EP4GF">Support (tteck)</a>
</p>

<p align="center">
<img alt="GitHub Repo stars" src="https://img.shields.io/github/stars/asylumexp/proxmox?style=flat">

## </p>

### About

Ports of tteck's proxmox scripts to ARM64.

Find the scripts in the website linked above.

Any issues with the scripts, please put an issue within this repository rather than upstream, as it is likely caused by my modifications.

### Support

If you would like to offer support, I would appreciate a star on the repository, or for you to support the creator of the Proxmox scripts [tteck on Ko-Fi](https://ko-fi.com/D1D7EP4GF)!

## VM Compatibility Guide

| Icon | Description                                        |
| ---- | -------------------------------------------------- |
| ☑️   | Creating the LXC using the script has been tested. |
| ⭕   | Install script is ported, but has not been tested. |
| ❌   | Unsupported. View notes for reason.                |
| 🔘   | Install script not ported to ARM64.                |

| OS                | Status | Notes                                             |
| ----------------- | ------ | ------------------------------------------------- |
| Debian            | ⭕     | Needs testing.                                    |
| Home Assistant OS | ❌     | Use Pimox HAOS VM script.                         |
| Mikrotik RouterOS | ❌     | No arm64 image available.                         |
| NextCloud         | ❌     | No arm64 image available. Not present on website. |
| OpenWRT           | ⭕     | Needs testing.                                    |
| OwnCloud          | ❌     | No arm64 image available.                         |
| Pimox HAOS        | ☑️     |                                                   |
| Ubuntu 22.04      | ⭕     | Needs testing.                                    |
| Ubuntu 24.04      | ⭕     | Needs testing.                                    |

## LXC Compatibility Guide

| App                             | Status | Notes                                                                                                    |
| ------------------------------- | ------ | -------------------------------------------------------------------------------------------------------- |
| Actual Budget                   | ☑️     |                                                                                                          |
| AdGuard Home                    | ☑️     |                                                                                                          |
| AgentDVR                        | ☑️     |                                                                                                          |
| Apache-Cassandra                | ☑️     |                                                                                                          |
| Alpine Docker                   | ☑️     |                                                                                                          |
| Alpine Grafana                  | ☑️     |                                                                                                          |
| Alpine                          | ☑️     |                                                                                                          |
| Alpine Nextcloud                | ☑️     |                                                                                                          |
| Alpine Vaultwarden              | ☑️     |                                                                                                          |
| Alpine Zigbee2mqtt              | ☑️     |                                                                                                          |
| Apache-CouchDB                  | ☑️     |                                                                                                          |
| Apt-Cacher-NG                   | ☑️     | Won't work with Debian template from before 2024/06/08 (need to delete tar /var/lib/vz/template/cache/). |
| Aria2                           | ☑️     |                                                                                                          |
| Audiobookshelf                  | ☑️     |                                                                                                          |
| Autobrr                         | ☑️     |                                                                                                          |
| Bazarr                          | ☑️     |                                                                                                          |
| Blocky                          | ☑️     |                                                                                                          |
| Caddy                           | ☑️     |                                                                                                          |
| Calibre-Web                     | ☑️     |                                                                                                          |
| CasaOS                          | ☑️     |                                                                                                          |
| Change Detection                | ☑️     |                                                                                                          |
| Channels DVR Server             | ☑️     |                                                                                                          |
| Cloudflared                     | ☑️     |                                                                                                          |
| CommaFeed                       | ☑️     |                                                                                                          |
| Cronicle Primary                | ☑️     |                                                                                                          |
| Dashy                           | ☑️     |                                                                                                          |
| deCONZ                          | ☑️     |                                                                                                          |
| Daemon Sync Server              | ❌     | Built for x64 only.                                                                                      |
| Debian                          | ☑️     |                                                                                                          |
| Deluge                          | ☑️     |                                                                                                          |
| Docker                          | ☑️     |                                                                                                          |
| Dockge                          | ☑️     |                                                                                                          |
| Emby Media Server               | ☑️     |                                                                                                          |
| EMQX                            | ☑️     |                                                                                                          |
| ErsatzTV                        | ☑️     |                                                                                                          |
| ESPHome                         | ☑️     |                                                                                                          |
| Fenrus                          | ☑️     |                                                                                                          |
| FHEM                            | ☑️     |                                                                                                          |
| FlareSolverr                    | ☑️     |                                                                                                          |
| FlowiseAI                       | ☑️     |                                                                                                          |
| Forgejo                         | ☑️     |                                                                                                          |
| Frigate                         | ☑️     |                                                                                                          |
| go2rtc                          | ☑️     |                                                                                                          |
| Gokapi                          | ☑️     |                                                                                                          |
| Gotify                          | ☑️     |                                                                                                          |
| Grafana                         | ☑️     |                                                                                                          |
| grocy                           | ☑️     |                                                                                                          |
| Heimdall Dashboard              | ☑️     |                                                                                                          |
| HiveMQ CE                       | ☑️     |                                                                                                          |
| Homarr                          | ☑️     |                                                                                                          |
| Home Assistant Core             | ☑️     |                                                                                                          |
| Home Assistant Container        | ☑️     |                                                                                                          |
| Homebridge                      | ☑️     |                                                                                                          |
| Homepage                        | ☑️     |                                                                                                          |
| Homer                           | ☑️     |                                                                                                          |
| HyperHDR                        | ☑️     |                                                                                                          |
| Hyperion                        | ☑️     |                                                                                                          |
| InfluxDB                        | ☑️     |                                                                                                          |
| ioBroker                        | ☑️     |                                                                                                          |
| iVentoy                         | ☑️     |                                                                                                          |
| Jackett                         | ☑️     |                                                                                                          |
| Jellyfin Media Server           | ☑️     |                                                                                                          |
| Jellyseerr                      | ☑️     |                                                                                                          |
| k0s                             | ☑️     |                                                                                                          |
| Kavita                          | ☑️     |                                                                                                          |
| Keycloak                        | ☑️     |                                                                                                          |
| Kubo                            | ☑️     |                                                                                                          |
| LazyLibrarian                   | ☑️     |                                                                                                          |
| Lidarr                          | ☑️     |                                                                                                          |
| Linkwarden                      | ☑️     |                                                                                                          |
| Mafl                            | ☑️     |                                                                                                          |
| MagicMirror Server              | ☑️     |                                                                                                          |
| Mariadb                         | ☑️     |                                                                                                          |
| Matterbridge                    | ☑️     |                                                                                                          |
| MediaMTX                        | ☑️     |                                                                                                          |
| Medusa                          | ☑️     |                                                                                                          |
| MeshCentral                     | ☑️     |                                                                                                          |
| MeTube                          | ☑️     |                                                                                                          |
| MongoDB                         | ☑️     | Only supports ARMv8.2-a currently. (no RPI4 support).                                                    |
| MotionEye NVR                   | ☑️     |                                                                                                          |
| MQTT                            | ☑️     |                                                                                                          |
| n8n                             | ☑️     |                                                                                                          |
| MySpeed                         | ☑️     |                                                                                                          |
| Navidrome                       | ☑️     |                                                                                                          |
| NextCloudPi                     | ☑️     |                                                                                                          |
| Nginx Proxy Manager             | ☑️     |                                                                                                          |
| NocoDB                          | ☑️     |                                                                                                          |
| Node-Red                        | ☑️     |                                                                                                          |
| Notifiarr                       | ☑️     |                                                                                                          |
| ntfy                            | ☑️     |                                                                                                          |
| OctoPrint                       | ☑️     |                                                                                                          |
| Omada Controller                | ☑️     |                                                                                                          |
| Ombi                            | ☑️     |                                                                                                          |
| OpenMediaVault                  | ☑️     |                                                                                                          |
| openHAB                         | ☑️     |                                                                                                          |
| OpenObserve                     | ☑️     |                                                                                                          |
| Overseerr                       | ☑️     |                                                                                                          |
| Owncast                         | ☑️     |                                                                                                          |
| PairDrop                        | ☑️     |                                                                                                          |
| Paperless-ngx                   | ☑️     |                                                                                                          |
| PBS                             | ☑️     | Proxmox Backup Server                                                                                    |
| PeaNUT                          | ☑️     |                                                                                                          |
| Petio                           | ☑️     | Only supports ARMv8.2-a currently. (no RPI4 support).                                                    |
| PhotoPrism                      | ☑️     |                                                                                                          |
| Pi.Alert                        | ☑️     |                                                                                                          |
| Pi-Hole                         | ☑️     |                                                                                                          |
| Pingvin Share                   | ☑️     |                                                                                                          |
| Plex Media Server               | ☑️     |                                                                                                          |
| Pocketbase                      | ☑️     |                                                                                                          |
| Podman Home Assistant Container | ☑️     |                                                                                                          |
| Podman                          | ☑️     |                                                                                                          |
| PostgreSQL                      | ☑️     |                                                                                                          |
| Prometheus                      | ☑️     |                                                                                                          |
| Prowlarr                        | ☑️     |                                                                                                          |
| qBittorrent                     | ☑️     |                                                                                                          |
| RabbitMQ                        | ☑️     |                                                                                                          |
| Radarr                          | ☑️     |                                                                                                          |
| RDTClient                       | ☑️     | Real-Debrid Torrent Client                                                                               |
| Readarr                         | ☑️     |                                                                                                          |
| Readeck                         | ☑️     |                                                                                                          |
| Redis                           | ☑️     |                                                                                                          |
| RTSPtoWeb                       | ☑️     |                                                                                                          |
| Runtipi                         | ☑️     |                                                                                                          |
| SABnzbd                         | ☑️     |                                                                                                          |
| Scrypted                        | ☑️     |                                                                                                          |
| Scrutiny                        | ☑️     |                                                                                                          |
| SFTPGo                          | ☑️     |                                                                                                          |
| Shinobi NVR                     | ☑️     |                                                                                                          |
| SmokePing                       | ☑️     |                                                                                                          |
| Sonarr                          | ☑️     |                                                                                                          |
| SpoolMan                        | ☑️     |                                                                                                          |
| Stirling-PDF                    | ☑️     |                                                                                                          |
| Syncthing                       | ☑️     |                                                                                                          |
| Tandoor Recipes                 | ☑️     |                                                                                                          |
| TasmoAdmin                      | ☑️     |                                                                                                          |
| Tautulli                        | ☑️     |                                                                                                          |
| Tdarr                           | ☑️     |                                                                                                          |
| Technitium DNS                  | ☑️     |                                                                                                          |
| Threadfin                       | ☑️     |                                                                                                          |
| Traccar                         | ☑️     |                                                                                                          |
| Traefik                         | ☑️     |                                                                                                          |
| Transmission                    | ☑️     |                                                                                                          |
| Trilium                         | ❌     | Built for x64 only.                                                                                      |
| Umami                           | ☑️     |                                                                                                          |
| Ubuntu                          | ☑️     |                                                                                                          |
| Umbrel                          | ☑️     |                                                                                                          |
| UniFi Network Server            | ☑️     |                                                                                                          |
| Unmanic                         | ☑️     |                                                                                                          |
| Uptime Kuma                     | ☑️     |                                                                                                          |
| Vaultwarden                     | ☑️     | Will probably work on default install if you have a lot of ram. Otherwise use the Alpine Linux version.  |
| Wastebin                        | ☑️     |                                                                                                          |
| WatchYourLAN                    | ☑️     |                                                                                                          |
| Whisparr                        | ☑️     |                                                                                                          |
| Whoogle                         | ☑️     |                                                                                                          |
| Wiki.js                         | ☑️     |                                                                                                          |
| WireGuard                       | ☑️     |                                                                                                          |
| YunoHost                        | ☑️     |                                                                                                          |
| Zabbix                          | ☑️     |                                                                                                          |
| Zigbee2MQTT                     | ☑️     |                                                                                                          |
| Zoraxy                          | ☑️     |                                                                                                          |
| Z-Wave JS UI                    | ☑️     |                                                                                                          |

## Miscellaneous Compatibility Guide

| Script         | Status | Notes                |
| -------------- | ------ | -------------------- |
| File Browser   | ☑️     |                      |
| OliveTin       | ☑️     |                      |
| NetBird        | ☑️     | No changes required. |
| Tailscale      | ☑️     | No changes required. |
| VS Code Server | ☑️     |                      |
