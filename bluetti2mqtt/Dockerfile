ARG BUILD_FROM
FROM $BUILD_FROM

# Copy data for add-on
COPY rootfs /

# Install bluetti_mqtt2
RUN pip install git+https://github.com/GHCMIS/bluetti_mqtt2.git@main \
	&& apk add --update --no-cache \
		bluez=5.65-r0 \
	&& rm -rf /var/cache/apk/* /lib/apk/db/* \
	&& chmod a+x /run.sh

CMD [ "/run.sh" ]
