FROM foggbh/lime-kaldi-worker:newest

WORKDIR /root
COPY make_transcript.sh /root/make_transcript.sh
RUN chmod +x make_transcript.sh

# CMD ["tail", "-f", "/dev/null"]
CMD ["/root/make_transcript.sh"]
