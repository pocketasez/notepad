FROM python:3.12.1-alpine3.19

RUN apk update && apk upgrade \
    && addgroup -S appgroup && adduser -S appuser -G appgroup \
    && apk --no-cache add musl-dev linux-headers g++ librdkafka librdkafka-dev \
    && python -m pip install --upgrade pip setuptools

# # ODBC ---- Uncomment below if using ODBC or BCP
RUN apk --no-cache add curl gnupg \
    && curl -O https://packages.microsoft.com/keys/microsoft.asc \
    && curl -O https://download.microsoft.com/download/3/5/5/355d7943-a338-41a7-858d-53b259ea33f5/msodbcsql18_18.3.2.1-1_amd64.apk \
    && curl -O https://download.microsoft.com/download/3/5/5/355d7943-a338-41a7-858d-53b259ea33f5/mssql-tools18_18.3.1.1-1_amd64.apk \
    && curl -O https://download.microsoft.com/download/3/5/5/355d7943-a338-41a7-858d-53b259ea33f5/msodbcsql18_18.3.2.1-1_amd64.sig \
    && curl -O https://download.microsoft.com/download/3/5/5/355d7943-a338-41a7-858d-53b259ea33f5/mssql-tools18_18.3.1.1-1_amd64.sig \
    && gpg --import microsoft.asc \
    && gpg --verify msodbcsql18_18.3.2.1-1_amd64.sig msodbcsql18_18.3.2.1-1_amd64.apk \
    && gpg --verify mssql-tools18_18.3.1.1-1_amd64.sig mssql-tools18_18.3.1.1-1_amd64.apk

RUN gpg --verify msodbcsql18_18.3.2.1-1_amd64.sig msodbcsql18_18.3.2.1-1_amd64.apk 
RUN gpg --verify mssql-tools18_18.3.1.1-1_amd64.sig mssql-tools18_18.3.1.1-1_amd64.apk

RUN apk add --allow-untrusted msodbcsql18_18.3.2.1-1_amd64.apk
RUN apk add --allow-untrusted mssql-tools18_18.3.1.1-1_amd64.apk
