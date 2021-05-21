FROM foggbh/lime-kaldi-base:latest

WORKDIR /root

# COPY simpsons.mp4 simpsons.mp4
# ENV LIMEKALDI_UID="bloppitybloppityboo"
# ENV LIMEKALDI_INPUT_BUCKET="limekaldi-input-bucket"
# ENV LIMEKALDI_INPUT_KEY="location/of/limekaldi/inputfile.mp4"
# ENV LIMEKALDI_OUTPUT_BUCKET="limekaldi-output-bucket"

COPY make_transcript.sh /root/make_transcript.sh
RUN chmod 755 make_transcript.sh

# install aws-cli
COPY awscli-exe-linux-x86_64.zip /root/awscli-exe-linux-x86_64.zip
RUN unzip awscli-exe-linux-x86_64.zip && aws/install

# CMD ["tail", "-f", "/dev/null"]
CMD ["./make_transcript.sh"]
