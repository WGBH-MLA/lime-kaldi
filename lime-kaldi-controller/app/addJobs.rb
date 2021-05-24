module JobStatus
  New = 0
  Working = 1
  Done = 2
  Fail  = 3
end
require 'mysql2'
require 'securerandom'
@client = Mysql2::Client.new(host: "lime-kaldi-mysql", username: "root", database: "limekaldi", password: "", port: 3306)

["cpb-aacip-528-4f1mg7gw76.mp3","cpb-aacip-528-4j09w0b17t.mp3","cpb-aacip-528-4q7qn60b7n.mp3","cpb-aacip-528-4t6f18tg85.mp3","cpb-aacip-528-4t6f18tg9g.mp3","cpb-aacip-528-4t6f18th2k.mp3","cpb-aacip-528-4x54f1nn4k.mp3","cpb-aacip-528-542j679z35.mp3","cpb-aacip-528-5d8nc5td6b.mp3","cpb-aacip-528-5d8nc5td8z.mp3",].each do |guid|

  uid = SecureRandom.uuid
  query = %(INSERT INTO jobs (uid, status, input_filepath) VALUES("#{uid}", #{JobStatus::New}, "#{guid}"))
  puts query
  resp = @client.query(query)
  puts resp
end
