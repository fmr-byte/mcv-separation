# mcv-separation

Isole la voix des spots publicitaires couverts par la musique (Demucs htdemucs), remet le volume à niveau (ffmpeg loudnorm) et renvoie la voix au bot Telegram MCV VEILLE, qui la transcrit et la classe.

Lancé par le bot (workflow_dispatch `separer`, entrée `envoi`). Secrets du dépôt : `WORKER_URL`, `SEPARATION_SECRET`. Aucun spot n'est enregistré dans ce dépôt ; les journaux n'affichent ni transcription ni marque.
