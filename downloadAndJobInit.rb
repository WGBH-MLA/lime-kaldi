module JobStatus
  New = 0
  Working = 1
  Done = 2
  Fail  = 3
end

module JobType
  # default
  CreateTranscript = 0
  DownloadFromCi = 1
  # can add more job types here for different settings/etc
end

require 'mysql2'
require 'securerandom'
@client = Mysql2::Client.new(host: "lime-kaldi-mysql", username: "root", database: "limekaldi", password: "", port: 3306)

queue_number = 0

# File.read("/root/app/dec22-combined.txt").split("\n").each do |guid|
#   uid = SecureRandom.uuid
#   puts "Adding DownloadFromCi Job for #{guid}..."
#   query = %(INSERT INTO jobs (uid, status, input_filepath, input_bucketname, job_type, queue_number) VALUES("#{uid}", #{JobStatus::New}, "#{ guid.gsub("\n", "") }", "lime-kaldi-input", #{ JobType::DownloadFromCi }, #{queue_number}))
#   puts "Adding job... #{query}"
#   resp = @client.query(query)
#   puts "Responded with: #{resp}"

#   # toggle to evenly distrubte between queues
#   queue_number = queue_number == 0 ? 1 : 0
# end


File.open("LISTRESULT-#{Time.now.strftime("%D-%T")}") do |f|


  File.read(ARGV[0]).split("\n").each do |guid|
    if noExistingRealReleasedTranscript(guid)
      if !checkifAlreadyDownloaded(guid)
        puts "#{guid} wasnt downloaded, adding download job!"
        addDownloadJob(guid)
      end






    # yes!
    
  end
end


def addDownloadJob(guid)
  query = %(INSERT INTO jobs (uid, status, input_filepath, input_bucketname, job_type, queue_number) VALUES("#{uid}", #{JobStatus::New}, "#{guid.gsub("\n", "")}.#{ext}", "lime-kaldi-input", #{ JobType::DownloadFromCi }, #{queue_number}))
  puts query
  resp = @client.query(query)
end

def addTranscriptJob(guid)
  uid = SecureRandom.uuid
  puts "Adding CreateTranscript Job for #{guid}..."
  resp = `aws s3api head-object --bucket lime-kaldi-input --key #{guid}.mp3`
  ext = resp.empty? ? "mp4" : "mp3"
  query = %(INSERT INTO jobs (uid, status, input_filepath, input_bucketname, job_type, queue_number) VALUES("#{uid}", #{JobStatus::New}, "#{guid.gsub("\n", "")}.#{ext}", "lime-kaldi-input", #{ JobType::CreateTranscript }, #{queue_number}))
  puts query
  resp = @client.query(query)
  puts resp

  # toggle to evenly distrubte between queues
  queue_number = queue_number == 0 ? 1 : 0
end


def checkifAlreadyDownloaded(guid)
  foundIt = false
  resp = `aws s3api head-object --bucket lime-kaldi-input --key "#{guid}.mp3"`
  if resp.empty?
    puts "no mp3 #{guid}"
  else
    puts "mp3 found #{guid}"
    foundIt = true
  end
  resp = `aws s3api head-object --bucket lime-kaldi-input --key "#{guid}.mp4"`
  if resp.empty?
    puts "no mp4 #{guid}"
  else
    puts "Found mp4 #{guid}"
    foundIt = true
  end

  foundIt
end


def hasExistingAAPBTranscriptFile(guid)
  xml = `curl -s https://americanarchive.org/catalog/#{guid}.pbcore`
  doc = Nokogiri::XML(xml)
  doc.remove_namespaces!
  ts_node = doc.xpath( %(/*/pbcoreAnnotation[@annotationType="Transcript URL"]) ).first
  ts_value = ts_node.text if ts_node

  if ts_value
    # ts value is the s3 URL
    if checkForTSFile(ts_value)
      puts "Found t file at #{ts_value}..."
      return true
    else
      puts "Found Transcript URL annotation containing #{ts_value} but annotated file wasnt there!"
      return false
    end

  else
    puts "No Transcript URL annotation for #{guid}, trying conventional locations for existing TS file..."

    idStyles(guid).each do |gstyle|
      puts "STYLE Checking #{gstyle}..."
      if checkForTSFile( s3URL(gstyle) )
        puts "Found TS File without annotation #{gstyle}... skipping"
        return true
      end
    end

    puts "STYLE Didn't find a TS file for #{guid} - swag."
    return false
  end
end
