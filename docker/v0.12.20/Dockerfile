FROM ubuntu:12.04
MAINTAINER Pierre Bellec <pierre.bellec@criugm.qc.ca>

# Update repository list
RUN apt-get update
RUN apt-get install python-software-properties -y
RUN apt-get update
RUN apt-add-repository ppa:octave/stable -y
RUN apt-get update

# Install dependencies available through apt-get
RUN apt-get install -y \
  bison \
  build-essential \
  cmake \
  cmake-curses-gui \
  flex \
  freeglut3 \
  freeglut3-dev \
  g++ \
  imagemagick \
  libjpeg62 \
  liboctave-dev
  libxi-dev \
  libxi6 \
  libxmu-dev \
  libxmu-headers \
  libxmu6 \
  octave \
  wget 
  
# Install Octave forge packages
RUN octave --eval "more off; pkg install -auto -global -forge -verbose control general signal image io statistics"

#Install MINC-toolkit
RUN mkdir /home/niak
RUN wget http://packages.bic.mni.mcgill.ca/minc-toolkit/Debian/minc-toolkit-1.9.2-20140730-Ubuntu_12.04-x86_64.deb -P /home/niak
RUN dpkg -i /home/niak/minc-toolkit-1.9.2-20140730-Ubuntu_12.04-x86_64.deb
RUN rm /home/niak/minc-toolkit-1.9.2-20140730-Ubuntu_12.04-x86_64.deb
RUN touch /.bashrc
RUN echo source /opt/minc-itk4/minc-toolkit-config.sh >> /.bashrc

# Install PSOM
RUN apt-get install unzip
RUN mkdir -p /home/niak/build/SIMEXP/
RUN cd /home/niak/build/SIMEXP && wget http://www.nitrc.org/frs/download.php/7065/psom-1.0.2.zip
RUN cd /home/niak/build/SIMEXP && unzip psom-1.0.2.zip
RUN rm /home/niak/build/SIMEXP/psom-1.0.2.zip

# Install NIAK
RUN mkdir -p /home/niak/build/SIMEXP
RUN cd /home/niak/build/SIMEXP && wget https://github.com/SIMEXP/niak/archive/v0.12.20.zip
RUN cd /home/niak/build/SIMEXP && unzip v0.12.20.zip
RUN rm /home/niak/build/SIMEXP/v0.12.20.zip

# Install BCT
RUN mkdir -p /home/niak/build/SIMEXP
RUN cd /home/niak/build/SIMEXP && wget https://sites.google.com/site/bctnet/Home/functions/BCT.zip
RUN cd /home/niak/build/SIMEXP && unzip BCT.zip
RUN rm /home/niak/build/SIMEXP/BCT.zip

# Build octave configure file
RUN echo more off >> /etc/octave.conf
RUN echo save_default_options\(\'-7\'\)\; >> /etc/octave.conf
RUN echo graphics_toolkit gnuplot >> /etc/octave.conf
RUN echo addpath\(genpath\(\"/home/niak/build/SIMEXP/\"\)\)\; >> /etc/octave.conf

# Commands for build and running
# docker build -t="pbellec/niak:v0.12.20" .
# docker run -i -t --name niak -v $HOME:$HOME --user $UID:$GID simexp/niak:0.12.20 /bin/bash -c "source /.bashrc && cd $HOME && octave"
# docker run -i -t --rm --name niak  -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=unix$DISPLAY -v $HOME:$HOME --user $UID:$GID simexp/niak:0.12.20 /bin/bash -c "source /.bashrc && export HOME=$HOME && cd $HOME && octave --force-gui"
