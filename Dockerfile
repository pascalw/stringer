FROM paintedfox/ruby

#RUN gem install bundler
#RUN apt-get -y install git libxml2-dev libxslt-dev libcurl4-openssl-dev libpq-dev libsqlite3-dev build-essential libreadline-dev

VOLUME /jenkins-slave/workspace/pascalw/stringer:/var/project
WORKDIR /var/project
