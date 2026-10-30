# JV Baiak - servidor Baiak Thunder (TFS 1.3, protocolo 8.60)
#
# Ubuntu 20.04 e o ambiente para o qual o Baiak Thunder foi preparado
# (exige fmt 6.1.2, que e a versao do 20.04). O codigo-fonte vem em ./fonte,
# preparado pelo instalador (commit fixo + patches do JV Baiak).

FROM ubuntu:20.04 AS build
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential cmake ca-certificates \
      libboost-system-dev libboost-filesystem-dev libboost-iostreams-dev \
      libcrypto++-dev libfmt-dev libgmp-dev libluajit-5.1-dev \
      libmariadb-dev libmariadb-dev-compat libpugixml-dev zlib1g-dev \
 && rm -rf /var/lib/apt/lists/*

COPY fonte/CMakeLists.txt /src/CMakeLists.txt
COPY fonte/cmake /src/cmake
COPY fonte/src /src/src
WORKDIR /src/build
RUN cmake -DCMAKE_BUILD_TYPE=Release .. \
 && make -j"$(nproc)" \
 && strip tfs

FROM ubuntu:20.04
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Sao_Paulo
# As mesmas bibliotecas da compilacao (os pacotes -dev puxam as de execucao).
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates tzdata \
      libboost-system-dev libboost-filesystem-dev libboost-iostreams-dev \
      libcrypto++-dev libgmp-dev libluajit-5.1-dev \
      libmariadb-dev libmariadb-dev-compat libpugixml-dev zlib1g-dev \
 && ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" > /etc/timezone \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --uid 1000 --create-home --shell /usr/sbin/nologin tfs

COPY --from=build /src/build/tfs /usr/local/bin/tfs

# /srv recebe do host: config.lua, key.pem e a pasta data/ (mapa, scripts, etc.)
WORKDIR /srv
USER tfs
EXPOSE 7171 7172
STOPSIGNAL SIGTERM
HEALTHCHECK --interval=30s --timeout=5s --start-period=180s --retries=3 \
  CMD bash -c 'exec 3<>/dev/tcp/127.0.0.1/7171' || exit 1
ENTRYPOINT ["/usr/local/bin/tfs"]
