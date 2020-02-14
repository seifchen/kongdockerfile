From centos:7
MAINTAINER  chenxuefeng<chenxuefeng1@guazi.com>

ENV KONG_VERSION=2.0.1 \
    PATH=$PATH:/usr/local/openresty/luajit/bin:/usr/local/openresty/nginx/sbin:/usr/local/openresty/bin \
    OPENSSL_DIR=/usr/local/openssl \
    GOPATH=/tmp/go \
    PATH=$GOPATH/bin:/usr/local/go/bin:$PATH

ARG KONG_URL=https://github.com/Kong/kong/archive/${KONG_VERSION}.tar.gz

ARG LUA_ROCKS_VERSION=3.1.3
ARG LUA_ROCKS_URL=https://luarocks.org/releases/luarocks-${LUA_ROCKS_VERSION}.tar.gz

ARG OPENRESTY_VERSION=1.15.8.2
ARG OPENRESTY_URL=https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz

ARG OPENRESTY_PATCHS_URL=https://github.com/Kong/openresty-patches/archive/master.tar.gz

ARG OPENSSL_VERSION=1.1.1b
ARG OPENSSL_URL=https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz

ARG SU_EXEC_VERSION=0.2
ARG SU_EXEC_URL="https://github.com/ncopa/su-exec/archive/v${SU_EXEC_VERSION}.tar.gz"

ARG LUA_KONG_NGINX_MODUEL_URL="https://github.com/Kong/lua-kong-nginx-module.git"


ADD docker-entrypoint.sh /

ARG GOLANG_VERSION=1.13.7
ARG KONG_GO_PLUGINSERVER_VERSION=master


RUN yum update -y && yum install -y  gcc  git m4  make  libyaml-devel wget  pcre-devel  patch zlib-devel libtool unzip perl perl-Data-Dumper \
    && curl -fsSLo go.tgz "https://golang.org/dl/go${GOLANG_VERSION}.linux-amd64.tar.gz" \
    && tar -C /usr/local -xzf go.tgz \
    && rm go.tgz \
    && export PATH="$PATH:/usr/local/go/bin" \
    && go version \
    && mkdir -p /tmp/go/src/github.com/kong/ \
    && git clone --branch ${KONG_GO_PLUGINSERVER_VERSION} https://github.com/Kong/go-pluginserver.git /tmp/go/src/github.com/kong/go-pluginserver \
    && cd /tmp/go/src/github.com/kong/go-pluginserver \
    && go mod tidy \
	&& cd /tmp/go/src/github.com/kong/go-pluginserver \
    && make build GOARCH=amd64 GOOS=linux \
    && mkdir -p /tmp/build/usr/local/bin/ \
    && mv go-pluginserver /usr/local/bin/ \
    && useradd --uid 1337 kong \
    && wget -c  "${SU_EXEC_URL}" -O - | tar -C /tmp -zx  \
    && make -C "/tmp/su-exec-0.2" \
    && cp "/tmp/su-exec-${SU_EXEC_VERSION}/su-exec" /usr/bin \
    && cd /tmp \
    && wget -c  "${OPENRESTY_URL}" -O -| tar -C /tmp -zx \
    && wget -c  "${LUA_ROCKS_URL}" -O -| tar -C /tmp -zx \
    && wget -c  "${OPENSSL_URL}" -O -| tar -C /tmp -zx  \
    && wget -c "${KONG_URL}" -O -| tar -C /tmp -zx  \
    && wget -c "${OPENRESTY_PATCHS_URL}" -O -| tar -C /tmp -zx  \
    && cd "openssl-${OPENSSL_VERSION}" && ./config --prefix=/usr/local/openssl enable-shared \
    && make && make install && make clean &&  cd /tmp \
    && ln -s /usr/local/openssl/bin/openssl  /usr/bin/openssl \ 
    && echo /usr/local/openssl/lib >> /etc/ld.so.conf.d/openssl.conf && ldconfig /etc/ld.so.conf \
    && cd "openresty-${OPENRESTY_VERSION}"/bundle/ \
    && for i in ../../openresty-patches-master/patches/${OPENRESTY_VERSION}/*.patch; do patch -p1 < $i; done \
    && cd /tmp && git clone ${LUA_KONG_NGINX_MODUEL_URL} \
    && cd /tmp/openresty-${OPENRESTY_VERSION} \
    &&  ./configure \
    --with-pcre-jit  \
    --with-stream_realip_module \
    --with-http_ssl_module \
    --with-http_realip_module  \
    --with-http_stub_status_module \
    --with-http_v2_module  \
    --with-cc-opt="-I/usr/local/openssl/include" \
    --with-ld-opt="-L/usr/local/openssl/lib"  \
    --add-module=/tmp/lua-kong-nginx-module \
    -j2 \
    && make -j2 && make install && make clean\
    && cd /tmp/lua-kong-nginx-module \
    && make install LUA_LIB_DIR=/usr/local/openresty/lualib/ \
    && cd /tmp/luarocks-${LUA_ROCKS_VERSION} \
    && ./configure --prefix=/usr/local --with-lua=/usr/local/openresty/luajit/ --lua-suffix=jit --with-lua-include=/usr/local/openresty/luajit/include/luajit-2.1 \
    && make build && make install && make clean \
    && cd /tmp/kong-${KONG_VERSION} && make install  && mv bin/kong /usr/local/bin/kong && cd /tmp \
    && unlink /etc/localtime && ln -s /usr/share/zoneinfo/Etc/GMT-8 /etc/localtime \
    && mkdir -p /usr/local/kong \
    && yum autoremove -y -q make gcc git   wget  patch  \
    && yum clean all -q \
    && chmod +x /docker-entrypoint.sh  \
    && chmod +x /usr/local/bin/kong \
    && rm -rf /usr/local/openssl/share/doc/* && rm -rf /usr/local/openssl/share/man/* \
    && rm -fr /var/cache/yum/* /tmp/* /root/.pki


EXPOSE 8000 8443 8001 8444

STOPSIGNAL SIGTERM

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["kong", "docker-start"]
