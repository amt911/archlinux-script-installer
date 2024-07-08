# PRIME Render on Wayland using NVIDIA GPU, since it is impossible to use
if [ "$(envycontrol -q)" = "nvidia" ] && [ "$XDG_SESSION_TYPE" = "wayland" ];
then
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
fi