#!/bin/bash
# grab output of 'how many pods', grep for passed in queue (first arg)
OUTPUT=$(kubectl --kubeconfig=/mnt/kubectl-secret --namespace=lime-kaldi get pods)
# check whether the command ended
if [ $(echo "$OUTPUT" | grep 'Unable to connect to the server: net/http: TLS handshake timeout' | wc -l) -eq 0 ]; then
  # give the actual number, because we succeeded in getting a result
  echo $(echo "$OUTPUT" | grep "^lime-kaldi-worker-$1" | wc -l)
else
  # we *did* get the TLS handshake error above, give a nonsense answer
  echo "-1"
fi
