FROM debian:buster-slim

ENV RPI_QEMU_KERNEL kernel-qemu-4.19.50-buster
ENV RPI_QEMU_KERNEL_COMMIT 8121f35cd6814ffbde5a18783eb04abb1c0c336a
ENV RASPBIAN_IMAGE 2020-02-13-raspbian-buster-lite
ENV RASPBIAN_IMAGE_URL https://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2020-02-14/

WORKDIR /root

# Install dependencies
RUN set -x \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        busybox \
        curl \
        qemu \
        qemu-system-arm \
        libguestfs-tools \
        unzip \
        linux-image-amd64 \
        netcat \
    && rm -rf /var/lib/apt/lists/

# Download image, kernel and DTB
RUN set -x \
    && curl -O $RASPBIAN_IMAGE_URL/$RASPBIAN_IMAGE.zip \
    && unzip $RASPBIAN_IMAGE.zip \
    && rm $RASPBIAN_IMAGE.zip \
    && curl https://raw.githubusercontent.com/dhruvvyas90/qemu-rpi-kernel/$RPI_QEMU_KERNEL_COMMIT/$RPI_QEMU_KERNEL > kernel-qemu-buster \
    && curl -O https://raw.githubusercontent.com/dhruvvyas90/qemu-rpi-kernel/$RPI_QEMU_KERNEL_COMMIT/versatile-pb.dtb

# Convert image to qcow2, resize it and enable SSH
RUN set -x \
    && qemu-img convert -f raw -O qcow2 $RASPBIAN_IMAGE.img raspbian-lite.qcow2 \
    && rm $RASPBIAN_IMAGE.img \
    && qemu-img resize raspbian-lite.qcow2 +2G \
    && guestfish --rw -m /dev/sda1 -a raspbian-lite.qcow2 write /ssh ""

EXPOSE 2222

HEALTHCHECK CMD ["nc", "-z", "-w5", "localhost", "2222"]

CMD ["qemu-system-arm", "-kernel", "kernel-qemu-buster", "-append", "root=/dev/sda2 rootfstype=ext4 rw'", "-hda", "raspbian-lite.qcow2", "-cpu", "arm1176", "-m", "256", "-machine", "versatilepb", "-no-reboot", "-dtb", "versatile-pb.dtb", "-nographic", "-net", "user,hostfwd=tcp::2222-:22", "-net", "nic"]
