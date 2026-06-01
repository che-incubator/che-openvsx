ARG OPENVSX_VERSION

FROM ghcr.io/eclipse-openvsx/openvsx-webui:${OPENVSX_VERSION} AS webui
FROM ghcr.io/eclipse-openvsx/openvsx-server:${OPENVSX_VERSION} AS server

FROM registry.access.redhat.com/ubi9/nodejs-24-minimal

USER 0

RUN microdnf install -y java-25-openjdk-headless && \
  microdnf clean all && \
  npm install -g ovsx

RUN groupadd -r openvsx && useradd --no-log-init -r -g openvsx openvsx

COPY /LICENSE /licenses/

RUN mkdir -p /home/openvsx/server
WORKDIR /home/openvsx/server

##############################################################################################
# Prepare Server component
ENV JVM_ARGS="-DSPDXParser.OnlyUseLocalLicenses=true -Xmx2048m"

COPY --from=server --chown=openvsx:openvsx /home/openvsx/ /home/openvsx/
RUN mkdir -p /home/openvsx/server/config && \
    chmod -R g+rwx /home/openvsx/server

##############################################################################################

##############################################################################################
# Prepare WebUI component
COPY --from=webui --chown=openvsx:openvsx /home/node/webui/dist/ BOOT-INF/classes/static/
##############################################################################################

COPY /server/scripts/run-server.sh /home/openvsx/server/
RUN chmod u+x /home/openvsx/server/run-server.sh

# Configure extensions storage
RUN mkdir -p /tmp/extensions && \
    chmod -R 777 /tmp/extensions

RUN chown -R openvsx:openvsx /home/openvsx
USER openvsx

# Run the start script
ENTRYPOINT ["./run-server.sh"]
