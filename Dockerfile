
FROM nginx:1.30.7-alpine

COPY site/ /usr/share/nginx/html/

ARG GIT_SHA=dev
ARG BUILD_DATE=local

RUN sed -i \
      -e "s|__GIT_SHA__|${GIT_SHA}|g" \
      -e "s|__BUILD_DATE__|${BUILD_DATE}|g" \
      /usr/share/nginx/html/index.html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q --spider http://127.0.0.1/ || exit 1

