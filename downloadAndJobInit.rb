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

require 'json'
require 'mysql2'
require 'securerandom'
require 'nokogiri'


@client = Mysql2::Client.new(host: "lime-kaldi-mysql", username: "root", database: "limekaldi", password: "", port: 3306)
queue_number = 0

#meffids

def addDownloadJob(guid, queue_number)
  uid = SecureRandom.uuid
  query = %(INSERT INTO jobs (uid, status, input_filepath, input_bucketname, job_type, queue_number) VALUES("#{uid}", #{JobStatus::New}, "#{guid}", "lime-kaldi-input", #{ JobType::DownloadFromCi }, #{queue_number}))
  puts query
  resp = @client.query(query)
end

def addTranscriptJob(guid, queue_number)
  uid = SecureRandom.uuid
  puts "Adding CreateTranscript Job for #{guid}..."
  ext = extByAAPBMediaType(guid)
  query = %(INSERT INTO jobs (uid, status, input_filepath, input_bucketname, job_type, queue_number) VALUES("#{uid}", #{JobStatus::New}, "#{guid}.#{ext}", "lime-kaldi-input", #{ JobType::CreateTranscript }, #{queue_number}))
  puts query
  resp = @client.query(query)
  puts resp

  # toggle to evenly distrubte between queues
  # queue_number = queue_number == 0 ? 1 : 0
  # leave as 0 for now ^
end

# is it in the limekaldi input folder
def alreadyDownloaded(guid)
  if fileExists("lime-kaldi-input", "#{guid}.mp3")
    return true
  else
    if fileExists("lime-kaldi-input", "#{guid}.mp4")
      return true
    end
  end

  return false
end

# is there any nonzero file in AAPB bucket for this guid
def hasExistingAAPBTranscriptFile(guid)
  idStyles(guid).each do |gstyle|
    # puts "STYLE Checking #{gstyle}..."

    fInfo = fileInfo( "americanarchive.org", "transcripts/#{guid}/#{guid}-transcript.json" )
    if fInfo && fInfo["Content-Length"] && fInfo["Content-Length"] > 0
      return true
    end
  end

  # puts "STYLE Didn't find a TS file for #{guid}."
  return false
end

def fileInfo(bucket, key)
  resp = `aws s3api head-object --bucket #{bucket} --key #{key}`
  return false if resp.empty?
  JSON.parse(resp)
end

def fileExists(bucket, file)
  s3_output = fileInfo(bucket, file)
  # ruby return value is "" for an s3 404
  s3_output && s3_output != ""
end

def idStyles(guid)
  guidstem = guid.gsub(/cpb-aacip./, '')
  # none in bucket  'cpb-aacip/'
  ['cpb-aacip-', 'cpb-aacip_'].map { |style| style + guidstem }
end

def normalizeGuid(guid)
  guid.gsub(/cpb-aacip./, 'cpb-aacip-')
end

def extByAAPBMediaType(guid)
  xml = `curl https://americanarchive.org/catalog/#{guid}.pbcore`
  doc = Nokogiri::XML(xml)
  doc.remove_namespaces!
  doc.xpath("/*/pbcoreInstantiation/instantiationMediaType").first == "Moving Image" ? "mp4" : "mp3"
end

File.open("LISTRESULT-#{Time.now.to_i}", "w+") do |f|
  f << %(guid,existingTranscriptFound,inputFileAlreadyDownloaded,addedTranscriptJob\n)
  puts "Lets gooo!!!"

  File.read(ARGV[0]).split("\n").each do |guid|
    existingTranscriptFound = false
    inputFileAlreadyDownloaded = false
    addedTranscriptJob = false

    guid = guid.gsub("\n", "")

    puts "Starting #{guid}..."

    existingTranscriptFound = hasExistingAAPBTranscriptFile(guid)
    if !existingTranscriptFound
      # there is nothing at loc in AAPB Bucket

      puts "No existing TS found for #{guid}"

      inputFileAlreadyDownloaded = alreadyDownloaded(guid)
      if !inputFileAlreadyDownloaded
        puts "#{guid} wasnt downloaded yet, adding download job!"
        addDownloadJob( normalizeGuid(guid), 0 )
      end
      
      puts "#{guid} wasnt transcripted yet, adding transcript job!"
      addTranscriptJob( normalizeGuid(guid), 1 )
      addedTranscriptJob = true
    else
      # some nonzero file was found at loc in AAPB Bucket
      puts "Found some sort of nonzero transcript file for #{guid}, skipping..."
    end

    # yes!
    f << %(#{guid},#{existingTranscriptFound},#{inputFileAlreadyDownloaded},#{addedTranscriptJob}\n)
  end
end
