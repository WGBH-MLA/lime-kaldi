File.readlines("/root/KS_GUIDsfortranscripts_2.txt").each do |guid|
  resp = `aws s3api head-object --bucket lime-kaldi-input --key "#{guid}.mp3"`
  if resp.empty?
    puts "no mp3"
  else
    puts "mp3 found"
  end
  resp = `aws s3api head-object --bucket lime-kaldi-input --key "#{guid}.mp4"`
  if resp.empty?
    puts "no mp4"
  else
    puts "Found mp4"
  end
end
