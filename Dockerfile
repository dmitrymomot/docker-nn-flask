FROM ubuntu:16.04

MAINTAINER Dmitry Momot <mail@dmomot.com>

RUN apt-get update && apt-get install -y --no-install-recommends apt-utils
RUN apt-get update && apt-get install -y python-mpltoolkits.basemap

RUN NVIDIA_GPGKEY_SUM=d1be581509378368edeec8c1eb2958702feedf3bc3d17011adbf24efacce4ab5 && \
    NVIDIA_GPGKEY_FPR=ae09fe4bbd223a84b2ccfce3f60f4b3d7fa2af80 && \
    apt-key adv --fetch-keys http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/7fa2af80.pub && \
    apt-key adv --export --no-emit-version -a $NVIDIA_GPGKEY_FPR | tail -n +5 > cudasign.pub && \
    echo "$NVIDIA_GPGKEY_SUM  cudasign.pub" | sha256sum -c --strict - && rm cudasign.pub && \
    echo "deb http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64 /" > /etc/apt/sources.list.d/cuda.list

ENV CUDA_VERSION 8.0.61
LABEL com.nvidia.cuda.version="${CUDA_VERSION}"
ENV NVIDIA_CUDA_VERSION $CUDA_VERSION

ENV CUDA_PKG_VERSION 8-0=$CUDA_VERSION-1
RUN apt-get update && apt-get install -y --no-install-recommends \
        cuda-nvrtc-$CUDA_PKG_VERSION \
        cuda-nvgraph-$CUDA_PKG_VERSION \
        cuda-cusolver-$CUDA_PKG_VERSION \
        cuda-cublas-8-0=8.0.61.2-1 \
        cuda-cufft-$CUDA_PKG_VERSION \
        cuda-curand-$CUDA_PKG_VERSION \
        cuda-cusparse-$CUDA_PKG_VERSION \
        cuda-npp-$CUDA_PKG_VERSION \
        cuda-cudart-$CUDA_PKG_VERSION && \
    ln -s cuda-8.0 /usr/local/cuda && \
    rm -rf /var/lib/apt/lists/*

RUN echo "/usr/local/cuda/lib64" >> /etc/ld.so.conf.d/cuda.conf && \
    ldconfig

# nvidia-docker 1.0
LABEL com.nvidia.volumes.needed="nvidia_driver"

RUN echo "/usr/local/nvidia/lib" >> /etc/ld.so.conf.d/nvidia.conf && \
    echo "/usr/local/nvidia/lib64" >> /etc/ld.so.conf.d/nvidia.conf

ENV PATH /usr/local/nvidia/bin:/usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH /usr/local/nvidia/lib:/usr/local/nvidia/lib64

# nvidia-container-runtime
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility

RUN apt-get update && apt-get install -y --no-install-recommends \
        cuda-core-$CUDA_PKG_VERSION \
        cuda-misc-headers-$CUDA_PKG_VERSION \
        cuda-command-line-tools-$CUDA_PKG_VERSION \
        cuda-nvrtc-dev-$CUDA_PKG_VERSION \
        cuda-nvml-dev-$CUDA_PKG_VERSION \
        cuda-nvgraph-dev-$CUDA_PKG_VERSION \
        cuda-cusolver-dev-$CUDA_PKG_VERSION \
        cuda-cublas-dev-8-0=8.0.61.2-1 \
        cuda-cufft-dev-$CUDA_PKG_VERSION \
        cuda-curand-dev-$CUDA_PKG_VERSION \
        cuda-cusparse-dev-$CUDA_PKG_VERSION \
        cuda-npp-dev-$CUDA_PKG_VERSION \
        cuda-cudart-dev-$CUDA_PKG_VERSION \
        cuda-driver-dev-$CUDA_PKG_VERSION && \
    rm -rf /var/lib/apt/lists/*

ENV LIBRARY_PATH /usr/local/cuda/lib64/stubs:${LIBRARY_PATH}


# Theano
# ================

ENV DNPY_NO_DEPRECATED_API=NPY_1_7_API_VERSION

RUN apt-get update && apt-get install -y \
    python-numpy \
    python-scipy \
    python-dev \
    python-nose \
    python-mysqldb \
    g++ \
    libopenblas-dev \
    git \
    curl

RUN curl -O https://bootstrap.pypa.io/get-pip.py && \
    python get-pip.py && \
    rm get-pip.py

RUN pip --no-cache-dir install Theano

# Optional dependencies for Theano

# Install cmake
RUN apt-get install -y software-properties-common && \
    add-apt-repository -y ppa:george-edison55/cmake-3.x && \
    apt-get update && \
    apt-get install -y cmake git
RUN pip install cython

RUN git clone https://github.com/Theano/libgpuarray.git && \
    cd libgpuarray && mkdir Build && cd Build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release && \
    make && make install && \
    cd .. && python setup.py build && \
    python setup.py install

# Because for nvidia docker image LD_LIBRARY_PATH comes changed.
ENV LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/local/lib"

RUN pip install pycuda pydot-ng \
    git+https://github.com/lebedov/scikit-cuda.git#egg=scikit-cuda

# Install other useful Python packages using pip
RUN pip --no-cache-dir install --upgrade ipython && \
    pip --no-cache-dir install \
        Cython \
        ipykernel \
        path.py \
        Pillow \
        pygments \
        six \
        sphinx \
        wheel \
        zmq \
        && \
    python -m ipykernel.kernelspec

# Install OpenCV
RUN apt-get update && apt-get install -y libopencv-dev python-opencv && \
    echo 'ln /dev/null /dev/raw1394' >> ~/.bashrc

# h5py is optional dependency for keras
RUN apt-get update && apt-get install -y libhdf5-dev libhdf5-serial-dev
RUN pip install keras h5py

# nltk
RUN apt-get update
RUN pip install --upgrade nltk


# Install uWSGI
RUN pip install uwsgi

# Standard set up Nginx
ENV NGINX_VERSION 1.9.11-1~jessie

RUN apt-key adv --keyserver hkp://pgp.mit.edu:80 --recv-keys 573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62 \
    && echo "deb http://nginx.org/packages/mainline/debian/ jessie nginx" >> /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y ca-certificates nginx=${NGINX_VERSION} gettext-base \
    && rm -rf /var/lib/apt/lists/*
# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log
EXPOSE 80 443
# Finished setting up Nginx

# Install CertBot
# RUN apt-get update \
    # && apt-get install software-properties-common \
    # && add-apt-repository ppa:certbot/certbot \
    # && apt-get update \
    # && apt-get install python-certbot-nginx \
    # && certbot --nginx

# Make NGINX run on the foreground
RUN echo "daemon off;" >> /etc/nginx/nginx.conf
# Remove default configuration from Nginx
RUN rm /etc/nginx/conf.d/default.conf
# Copy the modified Nginx conf
COPY nginx.conf /etc/nginx/conf.d/
# Copy the base uWSGI ini file to enable default dynamic uwsgi process number
COPY uwsgi.ini /etc/uwsgi/

# Install Supervisord
RUN apt-get update && apt-get install -y supervisor \
&& rm -rf /var/lib/apt/lists/*
# Custom Supervisord config
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# By default, allow unlimited file sizes, modify it to limit the file sizes
# To have a maximum of 1 MB (Nginx's default) change the line to:
# ENV NGINX_MAX_UPLOAD 1m
ENV NGINX_MAX_UPLOAD 0

CMD ["/usr/bin/supervisord"]

RUN apt-get update && apt-get install -y python-pyaudio && pip install apiai

RUN pip install astroid
RUN pip install Babel
RUN pip install blinker
RUN pip install colorama
RUN pip install flask
RUN pip install flask-restful
RUN pip install pymongo
RUN pip install redis
RUN pip install mysql-connector-python-rf
RUN pip install pymysql
RUN pip install python-memcached
RUN pip install python-telegram-bot
RUN pip install Flask-Cache
RUN pip install Flask-Babel
RUN pip install Flask-Compress
RUN pip install Flask-Login
RUN pip install Flask-Mail
RUN pip install Flask-Principal
RUN pip install Flask-WTF
RUN pip install flask-security flask-sqlalchemy flask-mongoengine
RUN pip install vk
RUN pip install pyowm
RUN pip install twilio
RUN pip install pywhatsapp yowsup2
RUN pip install viberbot
RUN pip install slackclient
RUN pip install healthcheck
RUN pip install itsdangerous
RUN pip install Jinja2
RUN pip install logilab-common
RUN pip install MarkupSafe
RUN pip install nose
RUN pip install passlib
RUN pip install pylint
RUN pip install pytz
RUN pip install requirements
RUN pip install six
RUN pip install speaklater
RUN pip install SQLAlchemy
RUN pip install Werkzeug
RUN pip install wheel
RUN pip install WTForms


# fixes trouble with openssl
RUN pip uninstall -y pyopenssl
RUN pip install pyopenssl


# Which uWSGI .ini file should be used, to make it customizable
ENV UWSGI_INI /app/uwsgi.ini

# URL under which static (not modified by Python) files will be requested
# They will be served by Nginx directly, without being handled by uWSGI
ENV STATIC_URL /static
# Absolute path in where the static files wil be
ENV STATIC_PATH /app/static

# If STATIC_INDEX is 1, serve / with /static/index.html directly (or the static URL configured)
# ENV STATIC_INDEX 1
ENV STATIC_INDEX 0

# Copy the entrypoint that will generate Nginx additional configs
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

# Add demo app
COPY ./app /app
WORKDIR /app

CMD ["/usr/bin/supervisord"]
