load-module module-tunnel-sink server=yume.local
load-module module-combine sink_name=combined slaves="tunnel-sink.yume.local,alsa_output.platform-byt-max98090.analog-stereo"

