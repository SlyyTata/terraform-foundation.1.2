# Using the official NGINX image from Docker Hub as the base image
FROM nginx:alpine

# Modify the default Nginx configuration in-place to listen on 8008 instead of 80
RUN sed -i 's/listen       80;/listen       8008;/g' /etc/nginx/conf.d/default.conf

# Set the working directory to the NGINX HTML directory
WORKDIR /usr/share/nginx/html

# Clean the default NGINX files
RUN rm -rf ./*

# This will now ONLY copy the whitelisted files from your .dockerignore
COPY . .

# Create index.html file to guarantee the directory is not empty
RUN echo '<h1>Hello from Fargate on Port 8008</h1>' > index.html

# Grant Nginx ownership and read rights to everything in this directory
RUN chmod -R 755 /usr/share/nginx/html && chown -R nginx:nginx /usr/share/nginx/html

# Expose port 8008 to allow traffic to the NGINX server
EXPOSE 8008

# Start NGINX when the container starts
CMD ["nginx", "-g", "daemon off;"]
