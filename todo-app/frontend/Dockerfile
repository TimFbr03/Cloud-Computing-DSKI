FROM nginx:alpine
COPY simple-build/ /usr/share/nginx/html/
RUN echo 'server { \
    listen 3000; \
    root /usr/share/nginx/html; \
    index index.html; \
    location /api/ { \
        proxy_pass http://todo-backend-service:3001/api/; \
    } \
}' > /etc/nginx/conf.d/default.conf
EXPOSE 3000
CMD ["nginx", "-g", "daemon off;"]
