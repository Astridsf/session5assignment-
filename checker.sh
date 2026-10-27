#!/bin/sh
# checker.sh — tjekker med jævne mellemrum om en web-service svarer,
# måler svartiden og skriver en linje i en logfil for hvert tjek.

# --- Indstillinger (kan overskrives med miljøvariabler) ---------------------
URL="${TARGET_URL:-http://web/}"        # hvem vi tjekker (service-navnet "web")
INTERVAL="${INTERVAL:-5}"               # sekunder mellem hvert tjek
TIMEOUT="${TIMEOUT:-3}"                 # opgiv hvis intet svar efter X sekunder
SLOW="${SLOW_THRESHOLD:-1}"             # svar på X sekunder eller mere = "SLOW"
LOG="${LOG_FILE:-/data/checker.log}"    # hvor loggen gemmes

echo "checker starter: tjekker $URL hvert ${INTERVAL}s (log: $LOG)"

# --- Uendelig løkke: tjek, log, vent, gentag --------------------------------
while true; do
    NOW=$(date '+%Y-%m-%d %H:%M:%S')

    # -s            : ingen progress-bar
    # -o /dev/null  : smid selve svaret (HTML'en) væk, vi skal kun bruge tallene
    # --max-time    : giv op efter TIMEOUT sekunder (så vi ikke hænger for evigt)
    # -w            : udskriv statuskode og svartid, fx "200 0.003512"
    RESULT=$(curl -s -o /dev/null --max-time "$TIMEOUT" \
                  -w '%{http_code} %{time_total}' "$URL")
    CURL_EXIT=$?    # curls exit code: 0 = ok, alt andet = netværksfejl

    CODE=$(echo "$RESULT" | cut -d' ' -f1)          # fx "200"
    TIME=$(echo "$RESULT" | cut -d' ' -f2)          # fx "0.003512"
    SECONDS_WHOLE=$(echo "$TIME" | cut -d. -f1)     # fx "0" (hele sekunder)

    # --- Afgør status ------------------------------------------------------
    if [ "$CURL_EXIT" -ne 0 ]; then
        # curl fik slet ikke et HTTP-svar. Exit-koden fortæller hvorfor:
        case "$CURL_EXIT" in
            6)  REASON="kan ikke finde host (DNS)" ;;
            7)  REASON="forbindelse afvist" ;;
            28) REASON="timeout efter ${TIMEOUT}s" ;;
            *)  REASON="curl-fejl $CURL_EXIT" ;;
        esac
        LINE="$NOW DOWN  $REASON"
    elif [ "$CODE" != "200" ]; then
        LINE="$NOW ERROR http=$CODE tid=${TIME}s"
    elif [ "$SECONDS_WHOLE" -ge "$SLOW" ]; then
        LINE="$NOW SLOW  http=$CODE tid=${TIME}s"
    else
        LINE="$NOW UP    http=$CODE tid=${TIME}s"
    fi

    # Skriv både til skærmen (docker compose logs) og til logfilen (>> = tilføj)
    echo "$LINE" | tee -a "$LOG"

    sleep "$INTERVAL"
done
