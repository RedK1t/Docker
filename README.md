# This is Docker


```bash
docker build -t kalinew .
```

```bash
docker run --name kfc -p 6080:6080 kalinew
```

```bash
docker build --progress=plain -t kalinew . 2>&1 | tee build.log
```

```bash
docker system prune -a
```