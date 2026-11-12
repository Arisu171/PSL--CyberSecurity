FROM handsonsecurity/seed-server:bind

COPY named.conf           /etc/bind/
COPY named.conf.options   /etc/bind/

RUN chmod 644 /etc/bind/named.conf /etc/bind/named.conf.options \
    && chown root:bind /etc/bind/named.conf /etc/bind/named.conf.options

CMD service named start && tail -f /dev/null
