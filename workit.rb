require './config/environment'
# ci = SonyCiBasic.new(credentials_path: Rails.root + 'config/ci.yml')

outputKeys=[]

File.read("NewMexico_GUIDstoaddtoKaldi.txt").split("\n").each do |guid|
  xml = `curl https://americanarchive.org/catalog/#{guid}.pbcore`
  puts "Grapped x for #{guid}"
  pb = PBCorePresenter.new(xml)

  ext = pb.audio? ? "mp3" : "mp4"
  puts "found ext #{ext}"  

  puts "Created pb for #{guid}"
  # ci_id = pb.ci_ids.first
  # puts "Got ci #{ci_id}"

  # puts "Going to download #{ci_url}"
  # File.open("dl/#{guid}.#{ext}", "wb") do |f|
  #   f.write( open( ci.download(ci_id) ) {|g| g.read } )
  # end

  # puts "got file, dope!"
  # puts `aws s3api put-object --bucket lime-kaldi-input --key #{guid}.#{ext} --body dl/#{guid}.#{ext}`

  outputKeys << %(#{guid}.#{ext})

  # puts "deleting #{guid}.#{ext}"
  # `rm dl/#{guid}.#{ext}`

  puts "done #{guid}, next!"
end

File.open("daOutputKeysNewMex.txt", "w+") do |f|
  outputKeys.each do |k|
    f << %(#{k}\n)
  end
end
