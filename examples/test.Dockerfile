FROM alpine:latest

# Install nginx
RUN apk add --no-cache nginx

# Create a simple index.html
RUN echo "<h1>Hello from Dockerfile!</h1>" > /var/lib/nginx/html/index.html

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"] 