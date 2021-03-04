FROM python:3.7.3

COPY --chown=www-data . /home/log_server
WORKDIR /home/log_server

RUN apt-get update \
    && apt-get install -y software-properties-common \
    && apt-get update \
    && apt-get install -y build-essential \
    git \
    locales \
    coreutils \
    gzip \
    ca-certificates \
    nginx \
    libssl-dev \
    curl \
    supervisor \

    && rm -rf /var/lib/apt/lists/* \
    && echo "daemon off;" >> /etc/nginx/nginx.conf \
    && rm /etc/nginx/sites-enabled/default

#  uwsgi log directory
RUN mkdir -p /var/log/uwsgi && chown -R www-data:www-data /var/log/uwsgi

RUN pip install -r /home/log_server/conf/requirements.txt

RUN ln -s /home/log_server/conf/nginx.conf /etc/nginx/sites-enabled/
RUN ln -s /home/log_server/conf/supervisor.conf /etc/supervisor/conf.d/

RUN echo Asia/Seoul | tee /etc/timezone && dpkg-reconfigure --frontend noninteractive tzdata

# locale
RUN sed -i '/en_US.UTF-8/s/^#//' /etc/locale.gen && locale-gen
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

EXPOSE 80

CMD ["supervisord", "-n"]