FROM python:3.6-alpine

COPY . /blog
WORKDIR /blog
VOLUME /blog

# 3.3 has no dumb-init nor tini, so we we have to download the binary manually.
# For that we need openssl, see: https://github.com/Yelp/dumb-init/issues/73.
ENV build_deps="openssl git"

RUN apk update && \
    apk add -u $build_deps && \
    wget -O /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.0/dumb-init_1.2.0_amd64 && \
    chmod +x /usr/local/bin/dumb-init && \
    git clone https://github.com/blogdown/blogdown && \
    pip install ./blogdown && \
    make icons && \
    apk del $build_deps && \
    rm -rf blogdown

EXPOSE 5000

ENTRYPOINT ["/usr/local/bin/dumb-init", "--"]
CMD ["run-blogdown", "serve"]
