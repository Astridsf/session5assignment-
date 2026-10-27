# Start fra Alpine Linux: et meget lille Linux-system (ca. 8 MB)
FROM alpine:3.20

# Installér det scriptet skal bruge: curl (til at kalde web-servicen)
RUN apk add --no-cache curl

# Arbejdsmappe inde i containeren
WORKDIR /app

# Kopiér scriptet fra vores mappe ind i image'et og gør det kørbart
COPY checker.sh .
RUN chmod +x checker.sh

# Mappe til logfilen
RUN mkdir -p /data

# Det der køres når containeren starter
CMD ["./checker.sh"]
