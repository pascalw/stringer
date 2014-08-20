FROM paintedfox/ruby

RUN gem install bundler
RUN bundle install --no-deployment -j 4
