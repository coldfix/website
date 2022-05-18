FROM python:3.10-alpine3.15

ARG UID=1000
RUN adduser -D -H -h /blog -u $UID blogger

RUN apk add -U git --virtual .build-deps && \
    apk add -U make imagemagick && \
    git clone https://github.com/blogdown/blogdown --depth 1 && \
    pip install ./blogdown && \
    apk del .build-deps && \
    rm -rf blogdown

EXPOSE 5000
USER blogger

COPY . /blog
WORKDIR /blog
VOLUME /blog

CMD ["./bin/blogdown", "serve"]
