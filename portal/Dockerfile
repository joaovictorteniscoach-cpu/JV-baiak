# JV Baiak - portal (site: contas, personagens, online, ranking, guilds, casas, eventos, downloads)
FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PASTA_DOWNLOADS=/app/downloads \
    CONFIG_LUA=/jogo/config.lua PASTA_DATA=/jogo/data TZ=America/Sao_Paulo
WORKDIR /app
COPY requirements.txt .
# uid 1000 = mesmo dono dos arquivos do servidor (para ler rates e eventos do config.lua, somente leitura)
RUN pip install --no-cache-dir -r requirements.txt \
 && useradd --uid 1000 --no-create-home --shell /usr/sbin/nologin portal
COPY app.py infos.py ./
COPY templates templates
COPY static static
USER portal
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s CMD python -c "import urllib.request;urllib.request.urlopen('http://127.0.0.1:8000/saude',timeout=3)"
# 1 processo com threads: o limite de criacao de contas por IP fica em memoria compartilhada
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "1", "--threads", "8", "--access-logfile", "-", "app:app"]
