FROM coturn/coturn:4.5.2-alpine

USER root

RUN apk add --no-cache bind-tools

# Override detect-external-ip.sh script
COPY ./detect-external-ip.sh /usr/local/bin/detect-external-ip.sh
RUN chmod +x /usr/local/bin/detect-external-ip.sh && \
    chown -R nobody:nogroup /var/lib/coturn/

USER nobody:nogroup
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["--log-file=stdout", "--external-ip=$(detect-external-ip)"]