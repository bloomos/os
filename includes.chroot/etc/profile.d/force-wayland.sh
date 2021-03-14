# Help some windowing systems along until they use wayland by default

export QT_QPA_PLATFORM
QT_QPA_PLATFORM=wayland

export QT_WAYLAND_DISABLE_WINDOWDECORATION
QT_WAYLAND_DISABLE_WINDOWDECORATION=1

export MOZ_ENABLE_WAYLAND
MOZ_ENABLE_WAYLAND=1

export GDK_GL
GDK_GL=gles
