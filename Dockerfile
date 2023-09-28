FROM fedora:38

LABEL description Robot Framework in Docker.

# By default, visual Percy tests won't run
ENV IS_VISUAL_TEST false

# Set the reports directory environment variable
ENV ROBOT_REPORTS_DIR /opt/robotframework/reports

# Set the tests directory environment variable
ENV ROBOT_TESTS_DIR /opt/robotframework/tests

# Set the working directory environment variable
ENV ROBOT_WORK_DIR /opt/robotframework/temp

# Setup X Window Virtual Framebuffer
ENV SCREEN_COLOUR_DEPTH 24
ENV SCREEN_HEIGHT 1080
ENV SCREEN_WIDTH 1920

# Setup the timezone to use, defaults to UTC
ENV TZ UTC

# Set number of threads for parallel execution
# By default, no parallelisation
ENV ROBOT_THREADS 1

# Define the default user who'll run the tests
ENV ROBOT_UID 1000
ENV ROBOT_GID 1000

# Dependency versions
ENV AXE_SELENIUM_LIBRARY_VERSION 2.1.6
ENV BROWSER_LIBRARY_VERSION 16.2.0
ENV CHROMIUM_VERSION 114.0
ENV DATABASE_LIBRARY_VERSION 1.2.4
ENV DATADRIVER_VERSION 1.8.1
ENV DATETIMETZ_VERSION 1.0.6
ENV DOCTEST_LIBRARY_VERSION 0.18.0
ENV FAKER_VERSION 5.0.0
ENV FIREFOX_VERSION 114.0
ENV FTP_LIBRARY_VERSION 1.9
ENV GECKO_DRIVER_VERSION v0.33.0
ENV IMAP_LIBRARY_VERSION 0.4.6
ENV PABOT_VERSION 2.16.0
ENV PERCY_VERSION 1.1.0
ENV REQUESTS_VERSION 0.9.5
ENV ROBOT_FRAMEWORK_VERSION 6.1
ENV SELENIUM_LIBRARY_VERSION 6.1.0
ENV SSH_LIBRARY_VERSION 3.8.0
ENV XVFB_VERSION 1.20

# Prepare binaries to be executed
COPY bin/chromedriver.sh /opt/robotframework/bin/chromedriver
COPY bin/chromium-browser.sh /opt/robotframework/bin/chromium-browser
COPY bin/run-tests-in-virtual-screen.sh /opt/robotframework/bin/

# Install system dependencies
RUN dnf upgrade -y --refresh \
  && dnf install -y \
    chromedriver \
    chromium \
    firefox \
    npm \
    nodejs \
    python3-pip \
    tzdata \
    xorg-x11-server-Xvfb-${XVFB_VERSION}* \
  && dnf clean all

# FIXME: below is a workaround, as the path is ignored
RUN mv /usr/lib64/chromium-browser/chromium-browser /usr/lib64/chromium-browser/chromium-browser-original \
  && ln -sfv /opt/robotframework/bin/chromium-browser /usr/lib64/chromium-browser/chromium-browser

# Tell Percy to skip downloading chromium and use the existing one
ENV PERCY_BROWSER_EXECUTABLE="/opt/robotframework/bin/chromium-browser"

# Install Robot Framework and associated libraries
RUN pip3 install \
  --no-cache-dir \
  percy-selenium==$PERCY_VERSION \
  robotframework==$ROBOT_FRAMEWORK_VERSION \
  robotframework-browser==$BROWSER_LIBRARY_VERSION \
  robotframework-databaselibrary==$DATABASE_LIBRARY_VERSION \
  robotframework-datadriver==$DATADRIVER_VERSION \
  robotframework-datadriver[XLS] \
  robotframework-datetime-tz==$DATETIMETZ_VERSION \
  robotframework-doctestlibrary==$DOCTEST_LIBRARY_VERSION \
  robotframework-faker==$FAKER_VERSION \
  robotframework-ftplibrary==$FTP_LIBRARY_VERSION \
  robotframework-imaplibrary2==$IMAP_LIBRARY_VERSION \
  robotframework-pabot==$PABOT_VERSION \
  robotframework-requests==$REQUESTS_VERSION \
  robotframework-seleniumlibrary==$SELENIUM_LIBRARY_VERSION \
  robotframework-sshlibrary==$SSH_LIBRARY_VERSION \
  axe-selenium-python==$AXE_SELENIUM_LIBRARY_VERSION \
  PyYAML \
  # Install an older Selenium version to avoid issues when running tests
  # https://github.com/robotframework/SeleniumLibrary/issues/1835
  selenium==4.9.0

# Install Percy CLI
RUN npm i -g @percy/cli
RUN chmod -R 777 /usr/local/lib/node_modules/@percy/cli/node_modules/@percy

# Gecko drivers
RUN dnf install -y \
    wget \

  # Download Gecko drivers directly from the GitHub repository
  && wget -q "https://github.com/mozilla/geckodriver/releases/download/$GECKO_DRIVER_VERSION/geckodriver-$GECKO_DRIVER_VERSION-linux64.tar.gz" \
  && tar xzf geckodriver-$GECKO_DRIVER_VERSION-linux64.tar.gz \
  && mkdir -p /opt/robotframework/drivers/ \
  && mv geckodriver /opt/robotframework/drivers/geckodriver \
  && rm geckodriver-$GECKO_DRIVER_VERSION-linux64.tar.gz \

  && dnf remove -y \
    wget \
  && dnf clean all

# Install the Node dependencies for the Browser library
# FIXME: Playright currently doesn't support relying on system browsers, which is why the `--skip-browsers` parameter cannot be used here.
RUN rfbrowser init

# Create the default report and work folders with the default user to avoid runtime issues
# These folders are writeable by anyone, to ensure the user can be changed on the command line.
RUN mkdir -p ${ROBOT_REPORTS_DIR} \
  && mkdir -p ${ROBOT_WORK_DIR} \
  && chown ${ROBOT_UID}:${ROBOT_GID} ${ROBOT_REPORTS_DIR} \
  && chown ${ROBOT_UID}:${ROBOT_GID} ${ROBOT_WORK_DIR} \
  && chmod ugo+w ${ROBOT_REPORTS_DIR} ${ROBOT_WORK_DIR}

# Allow any user to write logs
RUN chmod ugo+w /var/log \
  && chown ${ROBOT_UID}:${ROBOT_GID} /var/log

# Update system path and pythonpath
ENV PATH=/opt/robotframework/bin:/opt/robotframework/drivers:$PATH
ENV PYTHONPATH=$PYTHONPATH:${ROBOT_TESTS_DIR}

# Set up a volume for the generated reports
VOLUME ${ROBOT_REPORTS_DIR}

USER ${ROBOT_UID}:${ROBOT_GID}

# A dedicated work folder to allow for the creation of temporary files
WORKDIR ${ROBOT_WORK_DIR}

# Execute all robot tests
CMD ["run-tests-in-virtual-screen.sh"]
