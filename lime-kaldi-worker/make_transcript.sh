#!/bin/bash

# not to scale
# docker run --memory=10G --memory-swap=12G lime-kaldi

function done_file_exists {
  aws --endpoint-url 'http://s3-bos.wgbh.org' s3api head-object --bucket $LIMEKALDI_OUTPUT_BUCKET --key lime-kaldi-successes/$LIMEKALDI_UID.txt &> /dev/null
}

# write the video file to /root
local_input_filepath=/root/$(basename -- "$LIMEKALDI_INPUT_KEY")
aws s3api --endpoint-url 'http://s3-bos.wgbh.org' get-object --bucket $LIMEKALDI_INPUT_BUCKET --key $LIMEKALDI_INPUT_KEY $local_input_filepath

echo "When I need a snack..."
# get filename without mp4 extension
base=$(basename -- "$LIMEKALDI_INPUT_KEY")
filename_no_ext=$(echo "$base" | cut -f 1 -d '.' )
echo $base
outputwavpath=/root/audio_in_16khz/"$filename_no_ext"_16kHz.wav
echo $outputwavpath
outputjsonpath="/root/$filename_no_ext".json
echo $outputjsonpath

# use ffmpeg to get 16khz fiel
echo "Creating 16Khz wav of input file..."
ffmpeg -i $local_input_filepath -ac 1 -ar 16000 "$outputwavpath";

echo "I reach for audio files..."
#run that kaldi, baby!
/opt/kaldi/egs/american-archive-kaldi/sample_experiment/run.sh $outputwavpath $outputjsonpath

# create phrase level json with jq
word_json=$(jq ' [{} + .words[]|{"start_time": ( (((.time|tostring) + ".")|split(".")[0] + ".") + ( ((.time|tostring) + ".")|split(".")[1]   + "00" | .[0:2]) )         , "end_time": ( (((((.time|tonumber) + (.duration|tonumber))|tostring) + ".")|split(".")[0] + ".") + ( ((((.time|tonumber) + (.duration|tonumber))|tostring) + ".")|split(".")[1]   + "00" | .[0:2]) ) , "word_group" : ( (((.time|tonumber) + (.duration|tonumber))/ 5 + 1)|tostring|split(".")[0]|tonumber ) , "word" : .word }]' "$outputjsonpath" );

# write the json file to 'outputjsonpath'-transcript.json
finished_output_path="$outputjsonpath-transcript.json"
echo "$word_json" | jq --arg file_id "$(basename "$outputjsonpath" | sed -e 's#\..*$##g' | tr -d \")" --arg startoff "$(echo $word_json | jq -r ' .[0].start_time')" --argjson wgns "$(echo $word_json | jq -jc ' [.[].word_group]|unique')" '[ $wgns[] as $groupnum  |    [ .[] |   select(.word_group==$groupnum ) ]   |   {start_time:.[0].start_time,end_time:.[-1].end_time , text:[.[].word]|join(" "), speaker_id: ( ((((.[-1].end_time|tonumber) - ($startoff|tonumber)))/ 50 + 1)|tostring|split(".")[0]|tonumber )}   ] | {"id":$file_id,"language":"en-US","parts": . }' > $finished_output_path ;

# echo "Converting json to txt"
# ./json2txt.py

# upload file to object store
echo "Uploading $finished_output_path to object S3..."
aws --endpoint-url 'http://s3-bos.wgbh.org' s3api put-object --bucket $LIMEKALDI_OUTPUT_BUCKET --key "transcripts/$(basename -- "$finished_output_path")" --body $finished_output_path

echo "Great Job! $LIMEKALDI_INPUT_KEY" > ./donefile
aws --endpoint-url 'http://s3-bos.wgbh.org' s3api put-object --bucket $LIMEKALDI_OUTPUT_BUCKET --key lime-kaldi-successes/$DRTRANSCODE_UID.txt --body ./donefile
echo "Uploaded done file..."

echo "Im done!"