FROM alpine:3.19

RUN apk add --no-cache \
    bash \
    tar \
    gzip \
    curl \
    docker-cli \
    rclone \
    tzdata

# Set timezone
ENV TZ=Asia/Bangkok

# Copy rclone config
COPY rclone.conf /root/.config/rclone/rclone.conf

# Copy backup script
COPY backup.sh /usr/local/bin/backup.sh
RUN chmod +x /usr/local/bin/backup.sh

# Setup cron (every day at 2 AM Bangkok time)
RUN echo "0 2 * * * /usr/local/bin/backup.sh >> /var/log/backup.log 2>&1" > /etc/crontabs/root

# Create log file
RUN touch /var/log/backup.log

# Run crond in foreground
CMD ["crond", "-f", "-l", "2"]
