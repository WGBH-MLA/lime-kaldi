module JobStatus
  New = 0
  Working = 1
  Done = 2
  Fail  = 3
end
require 'mysql2'
require 'securerandom'
@client = Mysql2::Client.new(host: "lime-kaldi-mysql", username: "root", database: "limekaldi", password: "", port: 3306)

# main 4
File.readlines("Kansas_GUIDstoaddtoKaldi-split1.txt").each do |guid|
  uid = SecureRandom.uuid
  query = %(INSERT INTO jobs (uid, status, input_filepath, input_bucketname, job_type) VALUES("#{uid}", #{JobStatus::New}, "#{guid.gsub("\n", "")}.mp3", "lime-kaldi-input", 0))
  puts query
  resp = @client.query(query)
  puts resp
end


# b4
File.readlines("Kansas_GUIDstoaddtoKaldi-split2.txt").each do |guid|
  uid = SecureRandom.uuid
  query = %(INSERT INTO jobs (uid, status, input_filepath, input_bucketname, job_type) VALUES("#{uid}", #{JobStatus::New}, "#{guid.gsub("\n", "")}.mp3", "lime-kaldi-input", 1))
  puts query
  resp = @client.query(query)
  puts resp
end
