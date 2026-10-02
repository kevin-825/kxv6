# ==========================================
# Stage 1: Builder (QEMU from Source)
# ==========================================
FROM ubuntu:26.04 AS builder

USER root
ARG UID=1000
ARG GID=1000
ARG USERNAME="kevin"
ENV HOME=/home/$USERNAME
ENV DEBIAN_FRONTEND=noninteractive

RUN <<'EOF'
    #!/bin/bash
    set -euo pipefail
    echo ">>> [QEMU] Installing temporary build dependencies..."

    # Kept ONLY what is needed to compile QEMU with all optional features enabled
    apt-get update && apt-get install --no-install-recommends -y \
        sudo ca-certificates curl wget tar xz-utils \
        build-essential g++ autoconf automake libtool ccache \
        cmake ninja-build meson pkg-config \
        bc bison flex gawk device-tree-compiler \
        python3 python-is-python3 python3-venv \
        libglib2.0-dev libpixman-1-dev libfdt-dev zlib1g-dev \
        libgtk-3-dev libsdl2-dev libvte-2.91-dev libjpeg8-dev libbrlapi-dev libncurses-dev \
        libaio-dev liburing-dev librbd-dev libnfs-dev libiscsi-dev libcurl4-gnutls-dev \
        libslirp-dev libvdeplug-dev libssh-dev \
        libbz2-dev libsnappy-dev liblzo2-dev liblzma-dev libzstd-dev \
        libxen-dev libnuma-dev libibverbs-dev librdmacm-dev \
        libcapstone-dev libsasl2-dev libseccomp-dev libcap-ng-dev \
        libbabeltrace-dev libipt-dev libbluetooth-dev libelf-dev

    rm -rf /var/lib/apt/lists/*
EOF

ARG QEMU_VER="11.1.2"

RUN <<'EOF'
    #!/bin/bash
    set -euo pipefail

    TMP_DIR=$(mktemp -d)
    QEMU_URL="https://download.qemu.org/qemu-${QEMU_VER}.tar.xz"
    QEMU_TARGETS="arm-linux-user,armeb-linux-user,aarch64-linux-user,aarch64_be-linux-user,\
    arm-softmmu,aarch64-softmmu,riscv32-softmmu,riscv64-softmmu,riscv32-linux-user,riscv64-linux-user"

    echo ">>> [QEMU] Building from source..."
    curl -fSL "${QEMU_URL}" | tar -xJ -C "${TMP_DIR}"
    cd "${TMP_DIR}/qemu-${QEMU_VER}"
    ./configure --prefix=/opt/qemu --target-list="${QEMU_TARGETS}"
    make -j$(nproc)
    make install

    echo ">>> [QEMU] Purging build artifacts..."
    cd /
    rm -rf "${TMP_DIR}"
EOF


# ==========================================
# Stage 2: Final Development Image
# ==========================================
FROM ubuntu:26.04

LABEL maintainer="kevin@riscv.dev"
ENV DEBIAN_FRONTEND=noninteractive

ARG UID=1000
ARG GID=1000
ARG USERNAME="kevin"
ENV HOME=/home/$USERNAME
ARG WGET_ARGS="-q --show-progress --progress=bar:force:noscroll"

# Unified system packages & compatibility libraries
RUN <<'EOF'
    #!/bin/bash
    set -euo pipefail

    echo ">>> [Bootstrap] Installing core packages and dependencies..."
    apt-get update && apt-get install --no-install-recommends -y \
        sudo ca-certificates curl wget tar unzip xz-utils bzip2 gzip git git-core \
        locales software-properties-common lsb-release gnupg gpg-agent \
        uuid-runtime parallel tzdata \
        \
        libatomic1 libglib2.0-dev libglib2.0-0 libexpat1-dev libexpat1 \
        libmpfr-dev libmpfr6 libmpc-dev libmpc3 libncurses5-dev libncurses6 \
        libtinfo6 libncurses-dev guile-3.0-dev libelf-dev libssl-dev libyaml-dev \
        libaio1t64 libpixman-1-dev libpixman-1-0 libslirp-dev libslirp0 \
        liburing-dev liburing2 libgnutls28-dev libcapstone-dev libcapstone5 \
        libnuma-dev libnuma1 libiscsi-dev libiscsi7 libnfs-dev libnfs14 \
        libssh-dev libssh-4 librbd-dev librbd1 librados2 libepoxy0 \
        libsnappy-dev libsnappy1v5 libvdeplug-dev libvdeplug2t64 \
        libgtk-3-dev libgtk2.0-0 libgtk-3-0t64 libvte-2.91-dev libvte-2.91-0 \
        libbrlapi-dev libbrlapi0.8 libjpeg8 libgdk-pixbuf-2.0-0 \
        libcairo2-dev libcairo2 libx11-6 libsdl2-dev libsdl2-2.0-0 \
        libsdl1.2-dev libsndio-dev libfuse3-dev libpcap-dev libpopt0 liblocale-gettext-perl

    echo ">>> [FVP Dependencies] Fetching specific Python versions..."
    add-apt-repository -y ppa:deadsnakes/ppa
    apt-get update
    apt-get install -y --no-install-recommends libpython3.12 python3.9-dev

    echo ">>> [Stable] Applying System Workarounds..."
    lib_dir="/usr/lib/x86_64-linux-gnu"
    [ ! -e "${lib_dir}/libncurses.so.5" ] && ln -s "${lib_dir}/libncurses.so.6" "${lib_dir}/libncurses.so.5"
    [ ! -e "${lib_dir}/libncursesw.so.5" ] && ln -s "${lib_dir}/libncursesw.so.6" "${lib_dir}/libncursesw.so.5"
    [ ! -e "${lib_dir}/libtinfo.so.5" ] && ln -s "${lib_dir}/libtinfo.so.6" "${lib_dir}/libtinfo.so.5"

    if [ -f "/usr/bin/gnuinstall" ]; then
        update-alternatives --install /usr/bin/install install /usr/bin/gnuinstall 100
    fi

    apt-get autoremove --purge -y
    apt-get clean -y
    rm -rf /var/lib/apt/lists/*
EOF

# Initialize system locale
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8


# ==========================================
# 3. ARM & RISC-V Cross-Toolchains
# ==========================================
ARG ARM_GNU_TOOLCHAIN_VERSION=15.3.rel1
ENV ARM_GNU_TOOLCHAIN_VERSION=$ARM_GNU_TOOLCHAIN_VERSION
ARG RV_GNU_TOOLCHAIN_VERSION=2026.08.27
ENV RV_GNU_TOOLCHAIN_VERSION=$RV_GNU_TOOLCHAIN_VERSION

RUN --mount=type=bind,target=/build_context <<'EOF'
    set -euo pipefail
    TARGET_DIR="/opt/toolchains/aarch64-none-linux-gnu"
    TARBALL_NAME="arm-gnu-toolchain-${ARM_GNU_TOOLCHAIN_VERSION}-x86_64-aarch64-none-linux-gnu.tar.xz"
    DOWNLOAD_URL="https://gitlab.arm.com/api/v4/projects/tooling%2Fgnu-toolchains-for-arm/packages/generic/gnu-toolchain/${ARM_GNU_TOOLCHAIN_VERSION}/${TARBALL_NAME}"
    LOCAL_PATH="/build_context/${TARBALL_NAME}"
    mkdir -p "${TARGET_DIR}"
    #if local file exists, use it; otherwise, download from URL
    if [ -f "${LOCAL_PATH}" ]; then
        echo ">>> Using local tarball for aarch64-none-linux-gnu..."
        tar -xJ --strip-components=1 -f "${LOCAL_PATH}" -C "${TARGET_DIR}"
    else    
        echo ">>> Downloading aarch64-none-linux-gnu..."
        wget ${WGET_ARGS} -O- "${DOWNLOAD_URL}" \
            | tar -xJ --strip-components=1 -C "${TARGET_DIR}"
    fi
EOF

RUN --mount=type=bind,target=/build_context <<'EOF'
    set -euo pipefail
    TARGET_DIR="/opt/toolchains/aarch64_be-none-linux-gnu"
    TARBALL_NAME="arm-gnu-toolchain-${ARM_GNU_TOOLCHAIN_VERSION}-x86_64-aarch64_be-none-linux-gnu.tar.xz"
    DOWNLOAD_URL="https://gitlab.arm.com/api/v4/projects/tooling%2Fgnu-toolchains-for-arm/packages/generic/gnu-toolchain/${ARM_GNU_TOOLCHAIN_VERSION}/${TARBALL_NAME}"
    LOCAL_PATH="/build_context/${TARBALL_NAME}"
    mkdir -p "${TARGET_DIR}"
    if [ -f "${LOCAL_PATH}" ]; then
        echo ">>> Using local tarball for aarch64_be-none-linux-gnu..."
        tar -xJ --strip-components=1 -f "${LOCAL_PATH}" -C "${TARGET_DIR}"
    else
        echo ">>> Downloading aarch64_be-none-linux-gnu..."
        wget ${WGET_ARGS} -O- "${DOWNLOAD_URL}" \
            | tar -xJ --strip-components=1 -C "${TARGET_DIR}"
    fi
EOF

RUN --mount=type=bind,target=/build_context <<'EOF'
    set -euo pipefail
    TARGET_DIR="/opt/toolchains/arm-none-linux-gnueabihf"
    TARBALL_NAME="arm-gnu-toolchain-${ARM_GNU_TOOLCHAIN_VERSION}-x86_64-arm-none-linux-gnueabihf.tar.xz"
    DOWNLOAD_URL="https://gitlab.arm.com/api/v4/projects/tooling%2Fgnu-toolchains-for-arm/packages/generic/gnu-toolchain/${ARM_GNU_TOOLCHAIN_VERSION}/${TARBALL_NAME}"
    LOCAL_PATH="/build_context/${TARBALL_NAME}"
    mkdir -p "${TARGET_DIR}"
    if [ -f "${LOCAL_PATH}" ]; then
        echo ">>> Using local tarball for arm-none-linux-gnueabihf..."
        tar -xJ --strip-components=1 -f "${LOCAL_PATH}" -C "${TARGET_DIR}"
    else
        echo ">>> Downloading arm-none-linux-gnueabihf..."
        wget ${WGET_ARGS} -O- "${DOWNLOAD_URL}" \
            | tar -xJ --strip-components=1 -C "${TARGET_DIR}"
    fi
EOF

RUN --mount=type=bind,target=/build_context <<'EOF'
    set -euo pipefail
    TARGET_DIR="/opt/toolchains/riscv32-unknown-linux-gnu"
    TARBALL_NAME="riscv32-glibc-ubuntu-24.04-gcc.tar.xz"
    DOWNLOAD_URL="https://github.com/riscv-collab/riscv-gnu-toolchain/releases/download/${RV_GNU_TOOLCHAIN_VERSION}/${TARBALL_NAME}"
    LOCAL_PATH="/build_context/${TARBALL_NAME}"
    mkdir -p "${TARGET_DIR}"
    if [ -f "${LOCAL_PATH}" ]; then
        echo ">>> Using local tarball for riscv32-unknown-linux-gnu..."
        tar -xJ --strip-components=1 -f "${LOCAL_PATH}" -C "${TARGET_DIR}"
    else
        echo ">>> Downloading riscv32-unknown-linux-gnu..."
        wget ${WGET_ARGS} -O- "${DOWNLOAD_URL}" \
            | tar -xJ --strip-components=1 -C "${TARGET_DIR}"
    fi
EOF

RUN --mount=type=bind,target=/build_context <<'EOF'
    set -euo pipefail
    TARGET_DIR="/opt/toolchains/riscv64-unknown-linux-gnu"
    TARBALL_NAME="riscv64-glibc-ubuntu-24.04-gcc.tar.xz"
    DOWNLOAD_URL="https://github.com/riscv-collab/riscv-gnu-toolchain/releases/download/${RV_GNU_TOOLCHAIN_VERSION}/${TARBALL_NAME}"
    LOCAL_PATH="/build_context/${TARBALL_NAME}"
    mkdir -p "${TARGET_DIR}"
    if [ -f "${LOCAL_PATH}" ]; then
        echo ">>> Using local tarball for riscv64-unknown-linux-gnu..."
        tar -xJ --strip-components=1 -f "${LOCAL_PATH}" -C "${TARGET_DIR}"
    else
        echo ">>> Downloading riscv64-unknown-linux-gnu..."
        wget ${WGET_ARGS} -O- "${DOWNLOAD_URL}" \
            | tar -xJ --strip-components=1 -C "${TARGET_DIR}"
    fi
EOF

# ==========================================
# Copy QEMU from Builder Stage
# ==========================================
COPY --from=builder /opt/qemu /opt/qemu

# ==========================================
# STABLE BOOTSTRAP: Core OS, Compilers & Dev Tools
# ==========================================
RUN <<'EOF'
    #!/bin/bash
    set -euo pipefail

    apt-get update && apt-get install --no-install-recommends -y \
        build-essential autoconf automake libtool libtool-bin cmake \
        ninja-build bison flex gawk gcc g++ make pkg-config \
        device-tree-compiler thrift-compiler doxygen texinfo \
        \
        genimage dosfstools mtools fdisk gdisk parted cpio lz4 zstd \
        chrpath dfu-util srecord ovmf \
        \
        python3 python3-pip python-is-python3 python3-yaml python3-venv nodejs npm \
        \
        jq file dos2unix diffstat help2man net-tools iproute2 \
        rsync socat openssh-client graphviz \
        gdb gdb-multiarch gcovr lcov valgrind openocd usbutils udev kmod \
        openbox python3-xdg libpython3-dev x11vnc xvfb xterm
    
    # Install yq for YAML processing
    ARCH=$(dpkg --print-architecture)
    wget ${WGET_ARGS} "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${ARCH}" -O /usr/bin/yq
    chmod +x /usr/bin/yq

    apt-get autoremove --purge -y
    apt-get clean -y
    rm -rf /var/lib/apt/lists/*
EOF

# ==========================================
# 6. Python Virtual Environment & Embedded Tooling
# ==========================================
ENV PYTHON_VENV_PATH="/opt/venv"
# Pre-inject the venv bin path so tools are globally available without manual activation
ENV PATH="${PYTHON_VENV_PATH}/bin:${PATH}"

RUN <<'EOF'
    set -euo pipefail

    echo ">>> [Python] Initializing system-wide Virtual Environment..."
    python3 -m venv "${PYTHON_VENV_PATH}"

    # Activate for the remainder of this specific RUN block
    . "${PYTHON_VENV_PATH}/bin/activate"

    echo ">>> [Python] Upgrading core managers..."
    pip install --no-cache-dir --upgrade pip setuptools wheel

    echo ">>> [Python] Installing Embedded/RTOS requirements..."
    pip install --no-cache-dir \
        cryptography>=40.0.0 \
        intelhex \
        click \
        cbor2 \
        PyYAML \
        pytest \
        Jinja2>=2.10.3 \
        jsonschema>=3.2.0 \
        pyasn1 \
        imgtool>=1.9.0 \
        pyhsslms~=2.0.0 \
        ecdsa \
        kconfiglib \
        networkx~=3.1 \
        pyelftools \
        rich \
        libclang \
        'esptool>=5.0.2' \
        GitPython \
        junitparser \
        junit2html \
        nrf-regtool~=9.0.1 \
        numpy \
        protobuf \
        grpcio-tools \
        PyGithub \
        pylint \
        sh \
        statistics \
        west

    if [ "$(uname -m)" = "x86_64" ]; then
        echo ">>> [Python] Running pip check..."
        pip check
    fi
EOF


# ==========================================
# 5. Installing volatile packages
# ==========================================
RUN <<'EOF'
    #!/bin/bash
    set -euo pipefail
    echo ">>> [Dev Tools] Installing volatile packages..."
    apt-get update && apt-get install --no-install-recommends -y \
        zsh vim nano fzf fonts-powerline fonts-noto-cjk

	apt-get autoremove --purge -y
	apt-get clean -y
	rm -rf /var/lib/apt/lists/*
EOF

# ==========================================
# 6. User Creation & Shell Setup
# ==========================================
WORKDIR /home/${USERNAME}
ENV ZSH="/home/${USERNAME}/.oh-my-zsh"

RUN --mount=type=bind,target=/build_context <<'EOF'
    #!/bin/bash
    set -euo pipefail

    if id "ubuntu" &>/dev/null; then
        echo ">>> Removing default 'ubuntu' user to free up UID 1000"
        userdel -r ubuntu || true
    fi

    echo ">>> Creating user '${USERNAME}' with UID ${UID} and GID ${GID}"
    groupadd -g ${GID} -o ${USERNAME}
    useradd -u ${UID} -m -g ${USERNAME} -G sudo,plugdev -s /usr/bin/zsh ${USERNAME}

    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME}
    chmod 0440 /etc/sudoers.d/${USERNAME}

    # Install Oh-My-Zsh
    if [ -f /build_context/install_omz.sh ]; then
        echo ">>> Using local Oh-My-Zsh installer..."
        sh /build_context/install_omz.sh --unattended
    else
        curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o /tmp/install_omz.sh
        sh /tmp/install_omz.sh --unattended
        rm /tmp/install_omz.sh
    fi

    ZSH_CUSTOM="$ZSH/custom"

    # Install Plugins & Themes
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM}/plugins/zsh-autosuggestions
    git clone https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting
    git clone https://github.com/zsh-users/zsh-history-substring-search ${ZSH_CUSTOM}/plugins/zsh-history-substring-search
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM}/themes/powerlevel10k
    git clone --depth=1 https://github.com/sindresorhus/pure.git ${ZSH_CUSTOM}/themes/pure

    # Fix ownership for the entire home directory
    chown -R ${USERNAME}:${GID} "/home/${USERNAME}"
EOF


# ==========================================
# 8. Final Path Export & Entrypoint Config
# ==========================================
ENV PATH="${PYTHON_VENV_PATH}/bin:\
/opt/qemu/bin:\
/opt/fvp/bin:\
/opt/toolchains/arm-none-eabi/bin:\
/opt/toolchains/aarch64-none-elf/bin:\
/opt/toolchains/aarch64-none-linux-gnu/bin:\
/opt/toolchains/aarch64_be-none-linux-gnu/bin:\
/opt/toolchains/arm-none-linux-gnueabihf/bin:\
/opt/toolchains/riscv32-unknown-linux-gnu/bin:\
/opt/toolchains/riscv64-unknown-linux-gnu/bin:\
/opt/toolchains/riscv32-unknown-elf/bin:\
/opt/toolchains/riscv64-unknown-elf/bin:\
${PATH}"

COPY --chown=${USERNAME}:${GID} ./.zshrc ${HOME}/.zshrc
COPY --chown=${USERNAME}:${GID} ./entrypoint.sh /home/entrypoint.sh

RUN chown -R ${USERNAME}:${GID} ${PYTHON_VENV_PATH}
RUN chmod +x /home/entrypoint.sh

USER $USERNAME

ENV MyENV=devcontainer
VOLUME ["/workdir"]

ENTRYPOINT ["/home/entrypoint.sh"]
CMD ["zsh"]
