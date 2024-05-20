FROM citusdata/citus:12.1.3

RUN apt update && \ 
    apt install -y curl ca-certificates postgresql-common lsb-release && \
    install -d /usr/share/postgresql-common/pgdg && \
    curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc && \
    echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    apt update && \
    apt install -y postgresql-16-cron

RUN sed "s/shared_preload_libraries='citus'/shared_preload_libraries='citus,pg_cron'/" -i /usr/share/postgresql/postgresql.conf.sample