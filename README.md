FROM postgres:14-alpine3.18
ENV POSTGRES_PASSWORD docker
COPY marquez.sql /docker-entrypoint-initdb.d/
EXPOSE 5432

CREATE USER marquez;
ALTER USER marquez WITH PASSWORD 'marquez';
CREATE DATABASE marquez;
GRANT ALL PRIVILEGES ON DATABASE marquez TO marquez;
