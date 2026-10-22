
FROM nginx:alpine

ARG FAULTY_RELEASE=false

COPY index.html /usr/share/nginx/html/index.html

# The readiness endpoint exists in healthy releases.
# Deliberately omit it for the rollback demonstration.
RUN if [ "$FAULTY_RELEASE" != "true" ]; then \
      echo "healthy" > /usr/share/nginx/html/health.html; \
    fi

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
