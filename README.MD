# Premade template

there are 2 types of premade template.

1. Download plugin and does nothing
2. Download plugin and copy configuration files

for 1 you can view SMP as example (as it only download chunky)

and for 2 you can look at Void template, since it does copy void world and also download the latest version of FastAsyncWorldEdit

## Deploying

you can use podman to deploy. for local dev testing:

```bash
podman run -d --name paper-dev \
  --userns=keep-id:uid=1000,gid=1000 \
  -p 25565:25565 \
  -e VELOCITY_FORWARDING_SECRET=devsecret \
  -e SERVER_MEMORY=2G \
  -v /home/mrrpmeowfurry/server-templates/local-testing:/data:Z \
  ghcr.io/mineriftmc/paper-[version]:latest
```

add `--pull=always` if you want the newest build, or just `podman pull` it first.

## Notes:

- `VELOCITY_FORWARDING_SECRET` has to be set or the container dies on startup. any value works for local testing.
- eula is auto accepted, port is 25565, everything is in `/data`.
- `online-mode` is off since the server sits behind velocity.
- the `-v` path keeps your world/config between restarts. drop it if you don't care.
- `--userns=keep-id` is so the container's user 1000 maps to you, otherwise rootless podman makes it root inside and the mount isn't writable. make sure the dir is yours: `chown 1000:1000 /your/data/dir`.
- the `:Z` on the volume is a fedora/selinux thing because selinux (big likes)

other env vars you can set: `SERVER_NAME`, `SERVER_MEMORY`, `JAVA_MIN_MEMORY`, `MINERIFT_INSTALL_VIA=false` to skip installing ViaVersion/ViaBackwards

handy commands:

```bash
podman logs -f paper-dev # watch startup
podman exec -it paper-dev mc-send-to-console "say hello" # send console cmd
podman rm -f paper-dev # tear down
```
