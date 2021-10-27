#!/bin/bash

# not to scale
# docker run --memory=10G --memory-swap=12G lime-kaldi

function done_file_exists {
  aws s3api head-object --bucket $LIMEKALDI_OUTPUT_BUCKET --key lime-kaldi-successes/$LIMEKALDI_UID.txt &> /dev/null
}

# Check if this job is actually already done (we just rebooted)
if done_file_exists;
  then
    echo "Done file already exists, I've no purpose in this world... Goodbye!"
    exit 0
fi

# write the video file to /root
local_input_filepath=/root/$(basename -- "$LIMEKALDI_INPUT_KEY")
aws s3api get-object --bucket $LIMEKALDI_INPUT_BUCKET --key $LIMEKALDI_INPUT_KEY $local_input_filepath

echo "When I need a snack..."
# get filename without mp4 extension
base=$(basename -- "$LIMEKALDI_INPUT_KEY")
filename_no_ext=$(echo "$base" | cut -f 1 -d '.' )
echo $base
outputwavpath=/root/audio_in_16khz/"$filename_no_ext"_16kHz.wav
echo $outputwavpath
outputjsonpath="/root/$filename_no_ext"-transcript.json
echo $outputjsonpath

# use ffmpeg to get 16khz fiel
echo "Creating 16Khz wav of input file..."
ffmpeg -i $local_input_filepath -ac 1 -ar 16000 "$outputwavpath";

echo "I reach for audio files..."
#run that kaldi, baby!
/opt/kaldi/egs/american-archive-kaldi/sample_experiment/run.sh $outputwavpath $outputjsonpath

# create phrase level json with jq
word_json=$(jq ' [{} + .words[]|{"start_time": ( (((.time|tostring) + ".")|split(".")[0] + ".") + ( ((.time|tostring) + ".")|split(".")[1]   + "00" | .[0:2]) )         , "end_time": ( (((((.time|tonumber) + (.duration|tonumber))|tostring) + ".")|split(".")[0] + ".") + ( ((((.time|tonumber) + (.duration|tonumber))|tostring) + ".")|split(".")[1]   + "00" | .[0:2]) ) , "word_group" : ( (((.time|tonumber) + (.duration|tonumber))/ 5 + 1)|tostring|split(".")[0]|tonumber ) , "word" : .word }]' "$outputjsonpath" );

echo "$word_json" | jq --arg file_id "$(basename "$outputjsonpath" | sed -e 's#\..*$##g' | tr -d \")" --arg startoff "$(echo $word_json | jq -r ' .[0].start_time')" --argjson wgns "$(echo $word_json | jq -jc ' [.[].word_group]|unique')" '[ $wgns[] as $groupnum  |    [ .[] |   select(.word_group==$groupnum ) ]   |   {start_time:.[0].start_time,end_time:.[-1].end_time , text:[.[].word]|join(" "), speaker_id: ( ((((.[-1].end_time|tonumber) - ($startoff|tonumber)))/ 50 + 1)|tostring|split(".")[0]|tonumber )}   ] | {"id":$file_id,"language":"en-US","parts": . }' > $outputjsonpath ;

# echo "Converting json to txt"
# ./json2txt.py

# upload file to object store
echo "Uploading $outputjsonpath to object S3..."
aws s3api put-object --bucket $LIMEKALDI_OUTPUT_BUCKET --key "transcripts/$(basename -- "$outputjsonpath")" --body $outputjsonpath

echo "Great Job! $LIMEKALDI_INPUT_KEY" > ./donefile
aws s3api put-object --bucket $LIMEKALDI_OUTPUT_BUCKET --key lime-kaldi-successes/$LIMEKALDI_UID.txt --body ./donefile
echo "Uploaded done file..."

echo "Im done!"
