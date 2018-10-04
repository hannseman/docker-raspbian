FROM debian:stretch-slim

ENV RPI_QEMU_KERNEL kernel-qemu-4.9.59-stretch
ENV RPI_QEMU_KERNEL_COMMIT 813a28ec2ccaf7fc1380f61283b5e74f8d675de5
ENV RASPBIAN_IMAGE 2018-06-27-raspbian-stretch-lite
ENV RASPBIAN_IMAGE_URL http://director.downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2018-06-29/

WORKDIR /root

# Install dependencies
RUN set -x \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        busybox \
        curl \
        qemu \
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
    && curl https://raw.githubusercontent.com/dhruvvyas90/qemu-rpi-kernel/$RPI_QEMU_KERNEL_COMMIT/$RPI_QEMU_KERNEL > kernel-qemu-stretch \
    && curl -O https://raw.githubusercontent.com/dhruvvyas90/qemu-rpi-kernel/$RPI_QEMU_KERNEL_COMMIT/versatile-pb.dtb

# Convert image to qcow2, resize it and enable SSH
RUN set -x \
    && qemu-img convert -f raw -O qcow2 $RASPBIAN_IMAGE.img raspbian-lite.qcow2 \
    && rm $RASPBIAN_IMAGE.img \
    && qemu-img resize raspbian-lite.qcow2 +2G \
    && guestfish --rw -m /dev/sda1 -a raspbian-lite.qcow2 write /ssh ""

EXPOSE 2222

HEALTHCHECK CMD ["nc", "-z", "-w5", "localhost", "2222"]

CMD ["qemu-system-arm", "-kernel", "kernel-qemu-stretch", "-append", "root=/dev/sda2 rootfstype=ext4 rw'", "-hda", "raspbian-lite.qcow2", "-cpu", "arm1176", "-m", "256", "-machine", "versatilepb", "-no-reboot", "-dtb", "versatile-pb.dtb", "-nographic", "-net", "user,hostfwd=tcp::2222-:22", "-net", "nic"]
