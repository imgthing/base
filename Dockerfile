ARG FRANKENPHP_VERSION=1.2.5
ARG PHP_VERSION=8.3.11
ARG VIPS_VERSION=8.15.3

ARG GRAALVM_VERSION=22.3.3
ARG PDFTK_VERSION=3.3.3

FROM alpine:3.20 AS vips

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


FROM ghcr.io/graalvm/graalvm-ce:${GRAALVM_VERSION} AS graalvm

ARG PDFTK_VERSION

RUN gu install native-image

WORKDIR /build

RUN curl https://gitlab.com/api/v4/projects/5024297/packages/generic/pdftk-java/v${PDFTK_VERSION}/pdftk-all.jar --output pdftk-all.jar \
	&& curl https://gitlab.com/pdftk-java/pdftk/-/raw/v${PDFTK_VERSION}/META-INF/native-image/reflect-config.json --output reflect-config.json \
	&& curl https://gitlab.com/pdftk-java/pdftk/-/raw/v${PDFTK_VERSION}/META-INF/native-image/resource-config.json --output resource-config.json \
	&& native-image --static -jar pdftk-all.jar \
    	-H:Name=pdftk \
    	-H:ResourceConfigurationFiles='resource-config.json' \
    	-H:ReflectionConfigurationFiles='reflect-config.json' \
    	-H:GenerateDebugInfo=0


FROM dunglas/frankenphp:${FRANKENPHP_VERSION}-php${PHP_VERSION}-alpine

RUN install-php-extensions ffi opcache

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
COPY --from=graalvm /build/pdftk /usr/bin/pdftk

WORKDIR /app

RUN vips --vips-config
