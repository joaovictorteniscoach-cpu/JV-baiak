# JV Baiak - ponte WebSocket -> TCP (o navegador nao fala TCP puro com o servidor 8.60)
FROM python:3.12-slim
RUN pip install --no-cache-dir "websockify==0.11.0" \
 && useradd --uid 1002 --no-create-home --shell /usr/sbin/nologin ponte
USER ponte
EXPOSE 8080
ENTRYPOINT ["websockify", "--heartbeat=30"]
