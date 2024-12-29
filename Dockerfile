FROM alpine:latest
COPY backup-containers.sh /
RUN apk -Uuv add bash docker-cli apk-cron && rm /var/cache/apk/*
RUN /backup-containers.sh install
CMD echo "Starting cron runner"; /backup-containers.sh list && crond -f
