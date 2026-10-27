FROM alpine:3.22

RUN apk add --no-cache git git-daemon

EXPOSE 9418

ENTRYPOINT ["git"]
CMD ["daemon", "--reuseaddr", "--base-path=/git", "--export-all", "--informative-errors", "--listen=0.0.0.0", "--port=9418", "--verbose"]
