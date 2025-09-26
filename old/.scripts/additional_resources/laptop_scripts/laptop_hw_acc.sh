# Firefox hardware acceleration when NVIDIA GPU is used
if [ "$(envycontrol -q)" = "nvidia" ];
then
    export LIBVA_DRIVER_NAME=nvidia
    export MOZ_DISABLE_RDD_SANDBOX=1
    export NVD_BACKEND=direct
fi