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

File.readlines("/root/KS_GUIDsfortranscripts_2.txt").each do |guid|
  uid = SecureRandom.uuid

  puts "Adding DownloadFromCi Job for #{guid}..."
  query = %(INSERT INTO jobs (uid, status, input_filepath, input_bucketname, job_type, queue_number) VALUES("#{uid}", #{JobStatus::New}, "#{ guid.gsub("\n", "") }", "lime-kaldi-input", #{ JobType::DownloadFromCi }, #{queue_number}))
  puts "Adding job... #{query}"
  resp = @client.query(query)
  puts "Responded with: #{resp}"

  # toggle to evenly distrubte between queues
  queue_number = queue_number == 0 ? 1 : 0
end


# File.readlines("/root/KS_GUIDsfortranscripts_2.txt").each do |guid|
#   uid = SecureRandom.uuid

#   puts "Adding CreateTranscript Job for #{guid}..."

#   resp = `aws s3api head-object --bucket lime-kaldi-input --key "#{guid}.mp3"`
#   ext = resp.empty? ? "mp4" : "mp3"
#   query = %(INSERT INTO jobs (uid, status, input_filepath, input_bucketname, job_type, queue_number) VALUES("#{uid}", #{JobStatus::New}, "#{guid.gsub("\n", "")}.#{ext}", "lime-kaldi-input", #{ JobType::CreateTranscript }, #{queue_number}))
#   puts query
#   resp = @client.query(query)
#   puts resp

#   # toggle to evenly distrubte between queues
#   queue_number = queue_number == 0 ? 1 : 0
# end
