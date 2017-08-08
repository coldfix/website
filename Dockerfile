FROM python:3.6-alpine

COPY . /blog
WORKDIR /blog
VOLUME /blog

ARG build_deps="git"
ARG runtime_deps="dumb-init"
ARG blogger_uid=1000

RUN apk update && \
    apk add -u $build_deps $runtime_deps && \
    adduser -D -H -h /blog -u $blogger_uid blogger && \
    git clone https://github.com/blogdown/blogdown && \
    pip install ./blogdown && \
    apk del $build_deps && \
    rm -rf blogdown

EXPOSE 5000
USER blogdown

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["./blogdown", "serve"]
