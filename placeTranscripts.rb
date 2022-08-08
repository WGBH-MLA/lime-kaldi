require 'csv'
require 'json'

def fileInfo(bucket, key)
 `aws s3api head-object --bucket #{bucket} --key #{key}`
end

def fileExists(bucket, file)
  s3_output = fileInfo(bucket, file)
  # ruby return value is "" for an s3 404
  s3_output && s3_output != ""
end


# folderContents=`ls -l1`.split("\n")
# folderContents.delete("placeTranscripts.rb")
# transcriptFiles=folderContents



# great.
transcriptFiles = `aws s3api`



CSV.open("place-report-#{ Time.now.strftime("%m-%d-%Y-%H:%M") }.csv", "wb") do |csv|

  csv << ["Guid", "Existing Transcript Found", "Good Transcript"]

  existingTranscriptFound = false
  goodTranscript = true
  transcriptFiles.each do |tf|

    tf_guid = tf.gsub("-transcript.json", "")
    final_tf_location = %(transcripts/#{ tf_guid }/#{ tf })
    existingTranscriptFound = fileExists("americanarchive.org", final_tf_location )

    if !existingTranscriptFound

      begin
        jsonObj = JSON.parse( File.read(tf) )
        if jsonObj["parts"] && jsonObj["parts"].count > 0

          puts "Good New Transcript! Pump it! #{tf}"
          `aws s3api put-object --bucket americanarchive.org --key #{ final_tf_location } --body ./#{tf}`
          puts "Pump complete."

          puts "Removing input file..."
          `aws s3 mv s3://lime-kaldi-input/#{ tf_guid }.mp3 s3://lime-kaldi-input/processed`
          `aws s3 mv s3://lime-kaldi-input/#{ tf_guid }.mp4 s3://lime-kaldi-input/processed`

          puts "Moving output file to done folder..."
          # temporary bad output filenames
          `aws s3 mv s3://lime-kaldi-output/transcripts/#{ tf.gsub("-transcript.json", ".json-transcript.json") } s3://lime-kaldi-output/releasedToAAPB/#{ tf }`

          puts "Finished with #{tf}......"
        else
          
          puts "Yuck! Didnt think Id see this! #{tf}"
          goodTranscript = false
        end
      rescue JSON::ParserError => e

        puts "Found invalid json for #{tf} #{e.inspect}, skipping..."
        goodTranscript = false
      end

    else
      puts "Whoa! #{tf} was already found in bucket! Skipping..."
    end

    puts "Reporting... #{tf}"
    csv << [tf_guid, existingTranscriptFound, goodTranscript]
    goodTranscript = true
  end
end
