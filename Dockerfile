# Using the official NGINX image from Docker Hub as the base image
FROM nginx:alpine

# Set the working directory to the NGINX HTML directory
WORKDIR /usr/share/nginx/html

# Clean the default NGINX files
RUN rm -rf ./*

# This will now ONLY copy the whitelisted files from your .dockerignore
COPY . .

# Expose port 80 to allow traffic to the NGINX server
EXPOSE 8008

# Start NGINX when the container starts
CMD ["nginx", "-g", "daemon off;"]
