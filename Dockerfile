FROM google/cloud-sdk:alpine
WORKDIR /gcr-cleaner
RUN apk --update add jq
COPY . .