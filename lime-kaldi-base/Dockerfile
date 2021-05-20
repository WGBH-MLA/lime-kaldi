FROM kaldiasr/kaldi:latest

WORKDIR /root
RUN mkdir /root/audio_in_16khz

# just for json2txt
RUN apt-get update && apt-get install -y python-pip
RUN pip install ftfy==4.4.3
COPY json2txt.py /root/json2txt.py

# base img likes perl 4, and use jq for finishing step
RUN apt-get install -y libperl4-corelibs-perl libjson-perl libfile-slurp-tiny-perl jq

# download and unzip the american-archive-kaldi recipe from pua
WORKDIR /opt/kaldi/egs

# add in big ol model files
ADD https://lime-kaldi-model.s3.amazonaws.com/american-archive-kaldi.zip american-archive-kaldi.zip

# decompress them and then clear the zip
RUN unzip ./american-archive-kaldi.zip && rm american-archive-kaldi.zip
COPY path.sh /opt/kaldi/egs/american-archive-kaldi/sample_experiment/path.sh
COPY set-kaldi-path.sh /opt/kaldi/egs/american-archive-kaldi/sample_experiment/set-kaldi-path.sh

# maybe not necessary
RUN chmod +x /opt/kaldi/egs/american-archive-kaldi/sample_experiment/path.sh /opt/kaldi/egs/american-archive-kaldi/sample_experiment/set-kaldi-path.sh

# ~symlink wsj steps folder to our sample experiment, baby!~
RUN ln -sf /opt/kaldi/egs/wsj/s5/steps /opt/kaldi/egs/american-archive-kaldi/sample_experiment/steps
RUN ln -sf /opt/kaldi/egs/wsj/s5/utils /opt/kaldi/egs/american-archive-kaldi/sample_experiment/utils
