# discordAnimeStream
Anime streaming script in discord/zoom etc.
Based on https://github.com/pystardust/ani-cli <br>
Before launch:<br>
```bash
sudo modprobe v4l2loopback card_label="Discord stream" exclusive_caps=1

pactl load-module module-null-sink sink_name="virtual_speaker" sink_properties=device.description="virtual_speaker"

pactl load-module module-remap-source master="virtual_speaker.monitor" source_name="virtual_mic" source_properties=device.description="virtual_mic"
```
