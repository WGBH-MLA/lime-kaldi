FROM kaldiasr/kaldi:latest

WORKDIR /root

# for testing - these come in through config map in rancher
# COPY simpsons.mp4 simpsons.mp4
# ENV LIMEKALDI_UID="bloppitybloppityboo"
# ENV LIMEKALDI_INPUT_BUCKET="limekaldi-input-bucket"
# ENV LIMEKALDI_INPUT_KEY="location/of/limekaldi/inputfile.mp4"
# ENV LIMEKALDI_OUTPUT_BUCKET="limekaldi-output-bucket"

COPY make_transcript.sh /root/make_transcript.sh
RUN chmod 755 make_transcript.sh

RUN mkdir /root/audio_in_16khz

# just for json2txt
RUN apt-get update && apt-get install -y python-pip
RUN pip install ftfy==4.4.3
COPY json2txt.py /root/json2txt.py

# base img likes perl 4, and use jq for finishing step, get curl for model files
RUN apt-get install -y libperl4-corelibs-perl libjson-perl libfile-slurp-tiny-perl jq curl

# download and unzip the american-archive-kaldi recipe from pua
WORKDIR /opt/kaldi/egs
# RUN curl -o american-archive-kaldi.zip https://lime-kaldi-model.s3.amazonaws.com/american-archive-kaldi.zip && unzip ./american-archive-kaldi.zip

# add in big ol model files
ADD https://lime-kaldi-model.s3.amazonaws.com/american-archive-kaldi.zip american-archive-kaldi.zip
# decompress them and then clear the zip
RUN unzip ./american-archive-kaldi.zip && rm american-archive-kaldi.zip && ln -sf /opt/kaldi/ /kaldi

WORKDIR /root

# install aws-cli
COPY awscli-exe-linux-x86_64.zip /root/awscli-exe-linux-x86_64.zip
RUN unzip awscli-exe-linux-x86_64.zip && aws/install

# CMD ["tail", "-f", "/dev/null"]
CMD ["./make_transcript.sh"]
