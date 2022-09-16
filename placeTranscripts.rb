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
# transcriptFiles = `aws s3api`

# transcripts = JSON.parse(`aws s3api list-objects --bucket lime-kaldi-output --prefix "transcripts/" --page-size 1000`)
# File.open("transcriptsFolder.csv", "w+") do |f|
#   # transcripts = 

#   f << %(KEY,SIZE,LASTMODIFIED\n)
#   transcripts["Contents"].each do |ts|
#     f << %("#{ts["Key"]}","#{ts["Size"]}","#{ts["LastModified"]}"\n)
#   end
# end
# tran = File.read("transcriptsFolder.csv").split("\n").map {|t| t.gsub("transcripts/", "").split(",") }.map {|t| t[0] }
# aapb = File.read("releasedtoAAPBFolder.csv").split("\n").map {|t| t.gsub("releasedToAAPB/", "").split(",") }.map {|t| t[0] }





transcriptKeys = JSON.parse(`aws s3api list-objects --bucket lime-kaldi-output --prefix "transcripts/" --page-size 1000`)["Contents"].map {|obj| obj["Key"] }.reject {|key| key == "transcripts/" || key == "transcripts/.json-transcript.json" }

# PLACE TRANS
CSV.open("place-report-#{ Time.now.strftime("%m-%d-%Y-%H:%M") }.csv", "wb") do |csv|

  csv << ["Input Key", "Guid", "Existing Transcript Found", "Good Transcript"]

  existingTranscriptFound = false
  goodTranscript = true
  transcriptKeys.each do |inputKey|

    # get rid of lime-kaldi-output folder and account for some typos, can delete 2nd part after this run
    outputKeyFilename = inputKey.gsub("transcripts/", "").gsub(".json-transcript.json", "-transcript.json")
    localFilepath = %(transcriptsWorkFolder/#{outputKeyFilename})
    tf_guid = outputKeyFilename.gsub("-transcript.json", "")
    final_tf_location = %(transcripts/#{ tf_guid }/#{ outputKeyFilename })

    existingTranscriptFound = fileExists("americanarchive.org", final_tf_location )

    if !existingTranscriptFound

      begin

        # download the ts to local!
        `aws s3api get-object --bucket lime-kaldi-output --key #{inputKey} #{localFilepath}`

        jsonObj = JSON.parse( File.read(localFilepath) )
        if jsonObj["parts"] && jsonObj["parts"].count > 0

          puts "Good New Transcript! Pump it! #{inputKey}"
          `aws s3api put-object --bucket americanarchive.org --key #{ final_tf_location } --body #{localFilepath}`
          puts "Pump complete."

          puts "Removing input file..."
          `aws s3 mv s3://lime-kaldi-input/#{ tf_guid }.mp3 s3://lime-kaldi-input/processed`
          `aws s3 mv s3://lime-kaldi-input/#{ tf_guid }.mp4 s3://lime-kaldi-input/processed`

          # temporary bad output filenames
          # `aws s3 mv s3://lime-kaldi-output/#{inputKey} s3://lime-kaldi-output/releasedToAAPB/#{ outputKeyFilename }`

          puts "Finished with #{inputKey}......"
        else
          
          puts "Yuck! bad transcript! Skipping #{inputKey}"
          goodTranscript = false
        end
      rescue JSON::ParserError => e

        puts "Found invalid json for #{inputKey} #{e.inspect}, skipping..."
        goodTranscript = false
      end

    else
      puts "Whoa! #{inputKey} was already found in AAPB bucket at #{final_tf_location}! Moving to skipping..."
  
    end

    puts "Moving output file to done folder..."
    `aws s3 mv s3://lime-kaldi-output/#{inputKey} s3://lime-kaldi-output/releasedToAAPB/#{ outputKeyFilename }`

    puts "Reporting... #{inputKey}"
    csv << [inputKey, tf_guid, existingTranscriptFound, goodTranscript]
    goodTranscript = true
  end
end
