FROM nginx:1

RUN rm /etc/nginx/conf.d/default.conf

COPY ./nginx.conf /etc/nginx/conf.d/
COPY ./_site /usr/share/nginx/html/