module JobStatus
  New = 0
  Working = 1
  Done = 2
  Fail  = 3
end
require 'mysql2'
require 'securerandom'
@client = Mysql2::Client.new(host: "lime-kaldi-mysql", username: "root", database: "limekaldi", password: "", port: 3306)

File.readlines("transcript-guids.txt").each do |guid|
  uid = SecureRandom.uuid
  query = %(INSERT INTO jobs (uid, status, input_filepath, input_bucketname) VALUES("#{uid}", #{JobStatus::New}, "#{guid}", "lime-kaldi-input"))
  puts query
  resp = @client.query(query)
  puts resp
end
