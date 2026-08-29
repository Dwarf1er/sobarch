#!/bin/sh

current_im=$(fcitx5-remote -n 2>/dev/null)

case "$current_im" in
  keyboard-us)
    echo '{"text": "EN", "tooltip": "English (US)", "class": "en"}'
    ;;
  keyboard-ca)
    echo '{"text": "FR", "tooltip": "French (Canada)", "class": "fr"}'
    ;;
  hangul)
    echo '{"text": "한", "tooltip": "Korean (Hangul)", "class": "kr"}'
    ;;
  *)
    echo "{\"text\": \"?\", \"tooltip\": \"$current_im\", \"class\": \"unknown\"}"
    ;;
esac
