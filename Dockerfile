FROM python:3.6-alpine

COPY . /blog
WORKDIR /blog
VOLUME /blog

ARG build_deps="git"
ARG runtime_deps="dumb-init"

RUN apk update && \
    apk add -u $build_deps $runtime_deps && \
    git clone https://github.com/blogdown/blogdown && \
    pip install ./blogdown && \
    make icons && \
    apk del $build_deps && \
    rm -rf blogdown

EXPOSE 5000

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["run-blogdown", "serve"]
