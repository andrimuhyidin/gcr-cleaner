FROM google/cloud-sdk:alpine
WORKDIR /gcr-cleaner
RUN apk --update add jq
COPY . .
RUN chmod +x /gcr-cleaner/gcr-cleaner.sh