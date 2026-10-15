FROM nginx:alpine
WORKDIR /usr/share/nginx/html

# Clean the default NGINX files
RUN rm -rf ./*

# This will now ONLY copy the whitelisted files from your .dockerignore
COPY . .

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
