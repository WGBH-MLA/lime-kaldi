FROM foggbh/lime-kaldi-worker:newest

WORKDIR /root
COPY make_transcript.sh /root/make_transcript.sh
RUN chmod +x make_transcript.sh
# ~symlink wsj steps folder to our sample experiment, baby!~
RUN ln -sf /opt/kaldi/egs/wsj/s5/steps /opt/kaldi/egs/american-archive-kaldi/sample_experiment/steps
RUN ln -sf /opt/kaldi/egs/wsj/s5/utils /opt/kaldi/egs/american-archive-kaldi/sample_experiment/utils

# CMD ["tail", "-f", "/dev/null"]
CMD ["/root/make_transcript.sh"]
