# JV Baiak - servidor Baiak Thunder (TFS 1.3, protocolo 8.60)
#
# Ubuntu 20.04 e o ambiente para o qual o Baiak Thunder foi preparado
# (exige fmt 6.1.2, que e a versao do 20.04). O codigo-fonte vem em ./fonte,
# preparado pelo instalador (commit fixo + patches do JV Baiak).
# Funciona em x86_64 (Intel/AMD) e em arm64 (ex.: Oracle Cloud gratis).

FROM ubuntu:20.04 AS build
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential cmake ca-certificates git \
      libboost-system-dev libboost-filesystem-dev libboost-iostreams-dev \
      libcrypto++-dev libfmt-dev libgmp-dev \
      libmariadb-dev libmariadb-dev-compat libpugixml-dev zlib1g-dev \
 && rm -rf /var/lib/apt/lists/*

# LuaJIT 2.1 atual (commit fixo): o pacote do 20.04 e um beta de 2017 que
# tem problemas de memoria em arm64. A versao atual usa GC64 em todo 64 bits.
ARG LUAJIT_COMMIT=8ca762976ebc85ad9bde3e15f147a7e326e0dd01
RUN git init -q /luajit \
 && git -C /luajit remote add origin https://github.com/LuaJIT/LuaJIT.git \
 && git -C /luajit fetch -q --depth 1 origin "$LUAJIT_COMMIT" \
 && git -C /luajit checkout -q FETCH_HEAD \
 && make -C /luajit -j"$(nproc)" PREFIX=/usr/local \
 && make -C /luajit install PREFIX=/usr/local \
 && ldconfig

COPY fonte/CMakeLists.txt /src/CMakeLists.txt
COPY fonte/cmake /src/cmake
COPY fonte/src /src/src
WORKDIR /src/build
# Avisos de compilador nao viram erro (-Werror fora) e char com sinal em
# qualquer processador, como no x86 para o qual o codigo foi escrito.
RUN sed -i 's/ -Werror//' ../CMakeLists.txt \
 && cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS="-fsigned-char" .. \
 && make -j"$(nproc)" \
 && strip tfs \
 && ldd tfs | grep -q 'libluajit-5.1.so.2 => /usr/local/lib/'

FROM ubuntu:20.04
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Sao_Paulo
# As mesmas bibliotecas da compilacao (os pacotes -dev puxam as de execucao).
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates tzdata \
      libboost-system-dev libboost-filesystem-dev libboost-iostreams-dev \
      libcrypto++-dev libgmp-dev \
      libmariadb-dev libmariadb-dev-compat libpugixml-dev zlib1g-dev \
 && ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" > /etc/timezone \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --uid 1000 --create-home --shell /usr/sbin/nologin tfs

COPY --from=build /usr/local/lib/libluajit-5.1.so.2* /usr/local/lib/
COPY --from=build /src/build/tfs /usr/local/bin/tfs
RUN ldconfig && if ldd /usr/local/bin/tfs | grep 'not found'; then exit 1; fi

# /srv recebe do host: config.lua, key.pem e a pasta data/ (mapa, scripts, etc.)
WORKDIR /srv
USER tfs
EXPOSE 7171 7172
STOPSIGNAL SIGTERM
HEALTHCHECK --interval=30s --timeout=5s --start-period=180s --retries=3 \
  CMD bash -c 'exec 3<>/dev/tcp/127.0.0.1/7171' || exit 1
ENTRYPOINT ["/usr/local/bin/tfs"]
