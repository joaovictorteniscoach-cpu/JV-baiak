# JV Baiak - gerador dos clientes (Windows + Android). Roda sob demanda.
FROM eclipse-temurin:21-jre
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git zip unzip \
 && rm -rf /var/lib/apt/lists/*

# Assinador de APK (zipalign + assinatura v1/v2/v3), versao fixa e conferida.
RUN curl -fsSL --retry 5 -o /opt/uber-apk-signer.jar \
      https://github.com/patrickfav/uber-apk-signer/releases/download/v1.3.0/uber-apk-signer-1.3.0.jar \
 && echo "e1299fd6fcf4da527dd53735b56127e8ea922a321128123b9c32d619bba1d835  /opt/uber-apk-signer.jar" | sha256sum -c -

COPY visual/ /opt/jv/
COPY --chmod=755 gerar-clientes.sh /usr/local/bin/gerar-clientes
ENTRYPOINT ["/usr/local/bin/gerar-clientes"]
