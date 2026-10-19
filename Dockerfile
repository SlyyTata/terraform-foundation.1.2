# Using the official NGINX image from Docker Hub as the base image
FROM nginx:alpine

# ➔ NEW: Modify the default Nginx configuration in-place to listen on 8008 instead of 80
RUN sed -i 's/listen       80;/listen       8008;/g' /etc/nginx/conf.d/default.conf

# Set the working directory to the NGINX HTML directory
WORKDIR /usr/share/nginx/html

# Clean the default NGINX files
RUN rm -rf ./*

# This will now ONLY copy the whitelisted files from your .dockerignore
COPY . .

# Expose port 8008 to accurately document the container network intent
EXPOSE 8008

# Start NGINX when the container starts
CMD ["nginx", "-g", "daemon off;"]