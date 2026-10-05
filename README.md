<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/RedK1t/RedKit/main/docs/assets/logo-light.svg">
    <img src="https://raw.githubusercontent.com/RedK1t/RedKit/main/docs/assets/logo-dark.svg" alt="RedKit" width="96">
  </picture>
</p>

<h1 align="center">RedKit Kali Desktop</h1>

<p align="center">Kali Linux XFCE desktop in the browser over noVNC, with the RedKit proxy built in.<br>
Part of <a href="https://github.com/RedK1t/RedKit"><b>RedKit</b></a>, a modular, web-based penetration-testing framework.</p>

---

## What's inside

- Kali rolling + XFCE, served through noVNC on `:6080`
- The [RedKit Proxy](https://github.com/RedK1t/Proxy) backend on `:5050`, with Chromium preconfigured to route through it
- Desktop config under `assets/` (supervisord, panel, wallpaper, browser profile)

The [Orchestrator](https://github.com/RedK1t/Back-End) starts one of these containers per user (image name `kalinew`).

## Build and run

```bash
docker build -t kalinew .
docker run --name redkit-kali -p 6080:6080 -p 5050:5050 kalinew
```

Open <http://localhost:6080>. To see the full build log: `docker build --progress=plain -t kalinew . 2>&1 | tee build.log`.

## License

[MIT](LICENSE). For authorized security testing and education only. Only scan systems you own or have written permission to test.
