# Service Checker — Docker Compose

**Gruppe ROSA:** Astrid, Oscar, Rosalina og Sebastian

Et Docker-baseret setup med to services: en nginx-webserver og en checker-service, der løbende tjekker om webserveren er oppe, måler svartiden og logger resultatet.

---

## Hvad gør det?

`checker`-servicen kører et shell-script, der hvert 5. sekund laver en HTTP-anmodning til `web`-servicen med `curl`. For hvert tjek logger den HTTP-statuskode og svartid, og markerer om servicen er oppe, langsom eller nede. Outputtet skrives både til terminalen og til en logfil på din maskine under `./logs/checker.log`.

---

## Sådan kører du det

Kræver [Docker Desktop](https://www.docker.com/products/docker-desktop/) (skal være startet).

**1. Klon repositoriet**

```bash
git clone https://github.com/Astridsf/session5assignment-.git
cd session5assignment-
```

**2. Start services**

```bash
docker compose up --build
```

`--build` sørger for at `checker`-image'et bygges på ny, så ændringer i scriptet eller Dockerfilen kommer med.

Du vil se output som dette i terminalen:

```
checker-1  | checker starter: tjekker http://web/ hvert 5s (log: /data/checker.log)
web-1      | 172.18.0.3 - - [27/Oct/2026:12:35:10 +0000] "GET / HTTP/1.1" 200 896 "-" "curl/8.14.1" "-"
checker-1  | 2026-10-27 12:35:10 UP    http=200 tid=0.001590s
checker-1  | 2026-10-27 12:35:15 UP    http=200 tid=0.002800s
```

Linjerne fra `web-1` viser at nginx modtager kaldene fra checkeren — de to containere taler sammen.

Nginx er også tilgængelig i browseren på [http://localhost:8080](http://localhost:8080).
Logfilen oprettes automatisk under `./logs/checker.log`.

**3. Stop services**

Tryk `Ctrl+C`, og ryd derefter op med:

```bash
docker compose down
```

---

## Test at checkeren overlever nedbrud

Lad `docker compose up` køre, og åbn en ny terminal i samme mappe:

```bash
docker compose stop web
```

Checkeren skriver nu `DOWN` — men den crasher ikke, den prøver igen hvert 5. sekund:

```
checker-1  | 2026-10-27 12:36:43 DOWN  timeout efter 3s
```

Start webserveren igen:

```bash
docker compose start web
```

Checkeren går automatisk tilbage til `UP`.

---

## Filer og services

### `docker-compose.yml`
Definerer de to services og hvordan de hænger sammen:

- **`web`** — en standard nginx-webserver baseret på `nginx:alpine`. Det er den service, der bliver tjekket. Eksponerer port 8080 på din maskine, der mapper til port 80 inde i containeren.
- **`checker`** — vores script. Bygges fra `Dockerfile`. Modtager `TARGET_URL` og `INTERVAL` som miljøvariabler og mounter `./logs` ind i containeren (`/data`), så logfilen er tilgængelig på din maskine. `depends_on` sørger for at `web` startes først.

De to services er på samme Docker-netværk og finder hinanden via **service-navnet** — checkeren kalder `http://web/`, ikke en IP-adresse.

### `Dockerfile`
Bygger `checker`-containeren fra `alpine:3.20`. Installerer `curl` med `RUN apk add`, kopierer `checker.sh` ind og gør den eksekverbar. `CMD` starter scriptet automatisk når containeren starter.

### `checker.sh`
Selve checker-logikken. Kører en uendelig løkke, der hvert `INTERVAL` sekund kalder `TARGET_URL` med `curl` og logger én af fire statusser:

- `UP` — HTTP 200 inden for grænsen, med svartid
- `SLOW` — HTTP 200, men svartiden er `SLOW_THRESHOLD` sekunder eller mere
- `ERROR` — serveren svarede, men ikke med 200 (fx 404 eller 500)
- `DOWN` — intet svar. Årsagen logges ud fra curls exit code: host ikke fundet (DNS), forbindelse afvist eller timeout

Fordi `curl` har `--max-time`, hænger scriptet aldrig på en langsom service, og fordi fejl bare logges, kører det videre når servicen er nede eller ikke er startet endnu.

### `.gitignore`
Sørger for at logfiler (`logs/`, `*.log`) og `.DS_Store` ikke kommer med i Git.

### `logs/checker.log`
Oprettes automatisk af scriptet. Den ligger på din maskine via volume-mountet i `docker-compose.yml`, så den overlever at containerne bliver genstartet eller slettet.

---

## Miljøvariabler

| Variabel         | Standard            | Beskrivelse                                  |
|------------------|---------------------|----------------------------------------------|
| `TARGET_URL`     | `http://web/`       | URL der tjekkes                              |
| `INTERVAL`       | `5`                 | Sekunder mellem hvert tjek                   |
| `TIMEOUT`        | `3`                 | Sekunder før et tjek opgives (timeout)       |
| `SLOW_THRESHOLD` | `1`                 | Svartid i sekunder, der regnes som langsom   |
| `LOG_FILE`       | `/data/checker.log` | Logfilens placering inde i containeren       |

Standardværdierne står i toppen af `checker.sh`. De kan overskrives under `environment:` i `docker-compose.yml`.
