ARG PHP_VERSION=8.4.1
ARG VIPS_VERSION=8.16.0

ARG ALPINE=3.20

FROM ghcr.io/roadrunner-server/velox:latest AS rr-builder

RUN --mount=type=secret,id=RT_TOKEN,env=RT_TOKEN

COPY . /src

WORKDIR /src

ENV CGO_ENABLED=0
RUN vx build -c velox.toml -o /usr/bin/

FROM alpine:${ALPINE} AS vips

RUN apk add --no-cache \
	build-base \
    meson \
    glib-dev \
    zlib-dev \
    expat-dev \
    \
    gdk-pixbuf-dev \
    libimagequant-dev \
    fftw-dev \
    highway-dev \
    lcms2-dev \
    \
    libjxl-dev \
    libjpeg-turbo-dev \
    tiff-dev \
    libexif-dev \
    cgif-dev \
    libspng-dev \
    librsvg-dev \
    libwebp-dev \
    libheif-dev \
	poppler-dev \
    pango-dev

ARG VIPS_VERSION

RUN wget https://github.com/libvips/libvips/releases/download/v${VIPS_VERSION}/vips-${VIPS_VERSION}.tar.xz

RUN tar xf vips-${VIPS_VERSION}.tar.xz \
	&& cd vips-${VIPS_VERSION} \
	&& meson setup build  \
      --buildtype=release \
      -Ddeprecated=false  \
      -Dexamples=false  \
      -Dcplusplus=false  \
      -Dintrospection=disabled \
      -Dmodules=disabled \
	&& cd build \
	&& meson compile \
	&& meson install


FROM php:${PHP_VERSION}-cli-alpine${ALPINE}
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

RUN install-php-extensions ffi opcache sockets protobuf

RUN apk add --no-cache \
    glib \
    zlib \
    expat \
    \
    gdk-pixbuf \
    libimagequant \
    fftw \
    libhwy \
    lcms2 \
    \
    libjxl \
    libjpeg-turbo \
    tiff \
    libexif \
    cgif \
    libspng \
    librsvg \
    libwebpmux \
    libwebpdemux \
    libheif \
    poppler \
    poppler-glib \
    pango

COPY --from=vips /usr/local /usr/local
COPY --from=rr-builder /usr/bin/rr /usr/local/bin/rr

WORKDIR /app
RUN vips --vips-config
