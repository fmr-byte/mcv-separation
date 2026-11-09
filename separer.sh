#!/usr/bin/env bash
# Essais de séparation voix / musique, du plus rapide au plus lent.
# Chaque voix est remise à niveau (loudnorm) puis envoyée au bot, qui répond « ok » si Whisper la comprend.
# Rien de sensible n'est affiché (dépôt public).
set -uo pipefail

Q="id=$ENVOI&silencieux=$SILENCIEUX"
curl -sf -H "X-Cle: $SEPARATION_SECRET" "$WORKER_URL/separation/media?id=$ENVOI" -o entree.bin
ffmpeg -v error -y -i entree.bin -vn -ac 1 -ar 16000 -b:a 64k entree.mp3

# Remise à niveau puis essai auprès du bot. Renvoie 0 si le bot a compris la voix.
essayer() {
  local nom="$1" voix="$2"
  [ -s "$voix" ] || { echo "$nom : pas de voix produite"; return 1; }
  ffmpeg -v error -y -i "$voix" -af loudnorm -ar 16000 -ac 1 -sample_fmt s16 "essai-$nom.wav" || return 1
  local r
  r=$(curl -s -X POST -H "X-Cle: $SEPARATION_SECRET" -H "content-type: audio/wav" \
        --data-binary "@essai-$nom.wav" "$WORKER_URL/separation/essai?$Q&v=$nom")
  echo "$nom : $r"
  [ "$r" = "ok" ]
}

# 1. Space Demucs public sur GPU (le plus rapide, appartient à un tiers).
space() {
  local H=https://teamup-tech-demucs.hf.space P E U
  P=$(curl -sf --max-time 60 -F "files=@entree.mp3" "$H/gradio_api/upload" | python3 -c "import json,sys; print(json.load(sys.stdin)[0])") || return 1
  E=$(curl -sf --max-time 30 -X POST "$H/gradio_api/call/process" -H "content-type: application/json" \
        -d "{\"data\":[{\"path\":\"$P\",\"meta\":{\"_type\":\"gradio.FileData\"}},\"htdemucs\"]}" \
        | python3 -c "import json,sys; print(json.load(sys.stdin)['event_id'])") || return 1
  curl -s -N --max-time 180 "$H/gradio_api/call/process/$E" > sse.txt
  U=$(grep -o '"url": "[^"]*demucs_vocals.wav' sse.txt | head -1 | sed 's/"url": "//')
  [ -n "$U" ] && curl -sf --max-time 60 -o space.wav "$U"
}

# 2 à 4. Demucs sur cette machine, trois modèles.
demucs_local() {
  python -m demucs --two-stems=vocals -n "$1" -o sortie entree.mp3 > /dev/null 2>&1
}

if space; then essayer space space.wav && exit 0; else echo "space : indisponible"; fi
for modele in htdemucs mdx_extra htdemucs_ft; do
  demucs_local "$modele" && essayer "$modele" "sortie/$modele/entree/vocals.wav" && exit 0
done

# Aucun essai compris : le bot l'annonce dans le groupe.
curl -s -X POST -H "X-Cle: $SEPARATION_SECRET" "$WORKER_URL/separation/fin?$Q" > /dev/null
echo "aucun essai compris"
