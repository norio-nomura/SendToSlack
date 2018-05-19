ARG DOCKER_IMAGE
FROM ${DOCKER_IMAGE}
RUN useradd -m swiftbot
ADD . /VaporApp
RUN cd /VaporApp && \
    SWIFTPM_FLAGS="--configuration release --static-swift-stdlib" && \
    swift build $SWIFTPM_FLAGS && \
    mv `swift build $SWIFTPM_FLAGS --show-bin-path`/Run /usr/bin/VaporApp && \
    cd / && \
    rm -rf VaporApp

USER swiftbot
CMD VaporApp serve --env production --port $PORT --hostname 0.0.0.0
