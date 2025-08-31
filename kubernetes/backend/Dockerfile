FROM busybox:latest

# Create a simple HTTP server that returns pod and node info
RUN echo '#!/bin/sh' > /server.sh && \
    echo 'while true; do' >> /server.sh && \
    echo '  echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nHello from backend pod:$POD_NAME on node:$NODE_NAME" | nc -l -p 5678' >> /server.sh && \
    echo 'done' >> /server.sh && \
    chmod +x /server.sh

EXPOSE 5678

CMD ["/server.sh"]