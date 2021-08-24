require 'json'

def fileInfo(bucket, key)
 `aws s3api head-object --bucket #{bucket} --key #{key}`
end

def fileExists(bucket, file)
  s3_output = fileInfo(bucket, file)
  # ruby return value is "" for an s3 404
  s3_output && s3_output != ""
end


transcriptFiles=`ls -l1`.split("\n")
transcriptFiles.delete("placeTranscripts.rb")
# transcriptFiles = ["cpb-aacip-528-4q7qn60b7n-transcript.json"]
transcriptFiles.each do |tf|
  if !fileExists("americanarchive.org", tf)

    jsonObj = JSON.parse(File.read(tf))
    if jsonObj["parts"] && jsonObj["parts"].count > 0

      puts "New Transcript! Pump it! #{tf}"
      `aws s3api put-object --bucket americanarchive.org --key transcripts/#{tf} --body ./#{tf}`
      puts "Pump complete."
    else
      puts "Yuck! Didnt think Id see this!"
    end
  else
    puts "Whoa! #{tf} was already found in bucket!"
  end
end

