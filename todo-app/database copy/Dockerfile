FROM postgres:15

# Set environment variables
ENV POSTGRES_DB=todoapp
ENV POSTGRES_USER=todouser
ENV POSTGRES_PASSWORD=todopass

# Copy initialization script
COPY init.sql /docker-entrypoint-initdb.d/

# Expose PostgreSQL port
EXPOSE 5432

# Add health check
HEALTHCHECK --interval=10s --timeout=5s --retries=5 \
  CMD pg_isready -U $POSTGRES_USER -d $POSTGRES_DB

# PostgreSQL will start automatically via the base image