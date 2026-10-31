#!/usr/bin/env bash
# Instala o APK do site num celular Android virtual, abre, entra com a conta de teste
# e tira fotos da tela. Uso: android_emulador.sh <pasta-com-apk-e-conta.json> <pasta-fotos>
set -u
PASTA="$1"; FOTOS="$2"; mkdir -p "$FOTOS"
R="$FOTOS/resultado.txt"
n=0
foto() { n=$((n + 1)); adb exec-out screencap -p > "$FOTOS/$(printf %02d $n)-$1.png"; }
APK="$(ls "$PASTA"/*-Android.apk | head -n1)"
CONTA="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["conta"])' "$PASTA/conta.json")"
SENHA="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["senha"])' "$PASTA/conta.json")"
AAPT="$(ls -d "$ANDROID_HOME"/build-tools/*/aapt | tail -n1)"
PKG="$("$AAPT" dump badging "$APK" | sed -n "s/^package: name='\([^']*\)'.*/\1/p")"
echo "apk: $(basename "$APK") ($(du -h "$APK" | cut -f1)), pacote $PKG" | tee "$R"
echo "abis: $("$AAPT" dump badging "$APK" | grep native-code)" | tee -a "$R"
adb shell getprop ro.product.cpu.abilist | sed 's/^/emulador: /' | tee -a "$R"
adb install -r "$APK" 2>&1 | tail -n1 | sed 's/^/instalar: /' | tee -a "$R"
adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation 1   # deitado
adb logcat -c
inicio=$(date +%s)
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep 40
foto abriu
echo "processo vivo depois de 40 s: $(adb shell pidof "$PKG" >/dev/null && echo sim || echo NAO)" | tee -a "$R"
TAM="$(adb shell wm size | awk '{print $3}')"; echo "tela: $TAM" | tee -a "$R"
sleep 20
foto tela-de-login
# campo da conta: no layout de celular do OTClientV8 fica no centro, um pouco acima
L="${TAM%x*}"; A="${TAM#*x}"; [ "$L" -lt "$A" ] && { t=$L; L=$A; A=$t; }
adb shell input tap $((L / 2)) $((A * 40 / 100)); sleep 2
foto tocou-no-campo
adb shell input text "$CONTA"; sleep 1
adb shell input keyevent 61   # TAB
adb shell input text "$SENHA"; sleep 1
foto login-preenchido
adb shell input keyevent 66   # ENTER
sleep 12
foto depois-do-login
adb shell input keyevent 66; sleep 3
foto lista-de-personagens
adb shell input keyevent 66; sleep 15
foto entrou-no-jogo
adb shell input tap $((L * 58 / 100)) $((A * 40 / 100)); sleep 3
foto tocou-no-mapa
echo "processo vivo no fim ($(( $(date +%s) - inicio )) s): $(adb shell pidof "$PKG" >/dev/null && echo sim || echo NAO)" | tee -a "$R"
adb logcat -d | grep -iE "otclient|$PKG|FATAL|crash" | tail -n 300 > "$FOTOS/logcat.txt" || true
exit 0
