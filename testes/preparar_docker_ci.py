"""Mesmo Dockerfile/dependencias da VPS; transporte HTTPS para o build no CI.
O bundle do runner entra apenas como segredo BuildKit, sem desativar TLS/GPG.
"""
from pathlib import Path
import sys

root=Path(__file__).resolve().parents[1]
destino=Path(sys.argv[1])
texto=(root/'servidor-imagem/Dockerfile').read_text()
assert texto.count('RUN apt-get update')==2
opcoes='-o Acquire::https::CaInfo=/run/secrets/ci_ca -o Acquire::https::Timeout=25 -o Acquire::Retries=2'
montagem='--mount=type=secret,id=ci_ca,mode=0444,required=true'
texto=texto.replace('RUN apt-get update',
    'RUN '+montagem+' sed -i -e "s|http://archive.ubuntu.com/ubuntu|https://azure.archive.ubuntu.com/ubuntu|g" '
    '-e "s|http://security.ubuntu.com/ubuntu|https://azure.archive.ubuntu.com/ubuntu|g" /etc/apt/sources.list '
    '\\\n && apt-get '+opcoes+' update')
texto=texto.replace('apt-get install -y','apt-get '+opcoes+' install -y')
texto=texto.replace('RUN git init -q /luajit','RUN '+montagem+' git init -q /luajit')
texto=texto.replace('git -C /luajit fetch','git -c http.sslCAInfo=/run/secrets/ci_ca -C /luajit fetch')
texto=texto.replace('-j"$(nproc)"','-j2')
(destino/'Dockerfile').write_text(texto)
print('Dockerfile CI: mesmo fonte/dependencias, espelho Ubuntu Azure HTTPS, TLS e GPG verificados')
