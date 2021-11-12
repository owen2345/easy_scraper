FROM ruby:2.5-slim
RUN apt-get update && apt-get install -y ca-certificates wget gnupg
# install google chrome
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
RUN sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list'
RUN apt-get -y update
RUN apt-get install -y google-chrome-stable

# install chromedriver
RUN apt-get install -yqq unzip
RUN wget -O /tmp/chromedriver.zip http://chromedriver.storage.googleapis.com/`wget -qO-  chromedriver.storage.googleapis.com/LATEST_RELEASE`/chromedriver_linux64.zip
RUN unzip /tmp/chromedriver.zip chromedriver -d /usr/local/bin/

# set display port to avoid crash
ENV DISPLAY=:99

# Gem puma dependencies
RUN apt-get -qq -y install build-essential --fix-missing --no-install-recommends
ENV RACK_ENV=production
ENV DBUS_SESSION_BUS_ADDRESS="/dev/null"
RUN gem install bundler
WORKDIR /app
COPY . /app
RUN bundle install
EXPOSE 9494
CMD ["ruby", "server.rb"]

