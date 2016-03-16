DISPLAY=:0 x11vnc&
ssh -t -NR 5901:127.0.0.1:5900 myhost
