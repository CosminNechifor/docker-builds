ARG BASE_BUILDER_IMAGE=temporalio/base-builder:1.8.0
ARG BASE_SERVER_IMAGE=temporalio/base-server:1.9.0
ARG GOPROXY

##### Builder #####
FROM ${BASE_BUILDER_IMAGE} AS temporal-builder


WORKDIR /home/builder

# cache Temporal packages as a docker layer
COPY ./temporal/go.mod ./temporal/go.sum ./temporal/
RUN (cd ./temporal && go mod download all)

# cache tctl packages as a docker layer
COPY ./tctl/go.mod ./tctl/go.sum ./tctl/
RUN (cd ./tctl && go mod download all)

# build
COPY . .
RUN (cd ./temporal && make temporal-server)
RUN (cd ./tctl && make build)

##### Temporal server #####
FROM ${BASE_SERVER_IMAGE} as temporal-server
WORKDIR /etc/temporal

ENV TEMPORAL_HOME /etc/temporal
ENV SERVICES "history:matching:frontend:worker"
EXPOSE 6933 6934 6935 6939 7233 7234 7235 7239

# TODO switch WORKDIR to /home/temporal and remove "mkdir" and "chown" calls.
RUN addgroup -g 1000 temporal
RUN adduser -u 1000 -G temporal -D temporal
RUN mkdir /etc/temporal/config
RUN chown -R temporal:temporal /etc/temporal/config

# adding cloud proxy
# ADD https://storage.googleapis.com/cloudsql-proxy/v1.29.0/cloud_sql_proxy.linux.amd64 ./cloud_sql_proxy
# RUN chown temporal:temporal /etc/temporal/cloud_sql_proxy
# RUN chmod +x cloud_sql_proxy

USER temporal

# binaries
COPY --from=temporal-builder /home/builder/tctl/tctl /usr/local/bin
COPY --from=temporal-builder /home/builder/tctl/tctl-authorization-plugin /usr/local/bin
COPY --from=temporal-builder /home/builder/temporal/temporal-server /usr/local/bin

# configs
COPY ./temporal/config/dynamicconfig/docker.yaml /etc/temporal/config/dynamicconfig/docker.yaml
COPY ./temporal/docker/config_template.yaml /etc/temporal/config/config_template.yaml

# scripts
COPY ./docker/entrypoint.sh /etc/temporal/entrypoint.sh
COPY ./docker/start-temporal.sh /etc/temporal/start-temporal.sh

ENTRYPOINT ["/etc/temporal/entrypoint.sh"]
