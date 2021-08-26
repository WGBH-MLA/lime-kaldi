module JobStatus
  New = 0
  Working = 1
  Done = 2
  Fail  = 3
end
require 'mysql2'
require 'securerandom'
@client = Mysql2::Client.new(host: "lime-kaldi-mysql", username: "root", database: "limekaldi", password: "", port: 3306)

queue_number = 0

File.readlines("Kansas_GUIDstoaddtoKaldi-split1.txt").each do |guid|
  uid = SecureRandom.uuid
  query = %(INSERT INTO jobs (uid, status, input_filepath, input_bucketname, job_type, queue_number) VALUES("#{uid}", #{JobStatus::New}, "#{guid.gsub("\n", "")}.mp3", "lime-kaldi-input", 0, #{queue_number}))
  puts query
  resp = @client.query(query)
  puts resp

  # toggle to evenly distrubte between queues
  queue_number = queue_number == 0 ? 1 : 0
end
