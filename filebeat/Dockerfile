ARG BUILD_FROM
FROM $BUILD_FROM

COPY rootfs /

ARG BUILD_ARCH

RUN \
    FB_VERSIONS="7.17.4 8.0.1 8.1.3 8.2.3" && \
    find /opt -iname *.yml | xargs chmod 644 && \
    for ver in $FB_VERSIONS; do echo "Downloading from: https://glab.bulletproof.rs/mtodoric/hassio-filebeat-binaries/-/raw/main/${ver}/${BUILD_ARCH}/filebeat"; curl -s --fail --output /bin/filebeat-$ver "https://glab.bulletproof.rs/mtodoric/hassio-filebeat-binaries/-/raw/main/${ver}/${BUILD_ARCH}/filebeat"; chmod +x /bin/filebeat-$ver; done && \
    rm -rf /env

CMD [ "/run.sh" ]
