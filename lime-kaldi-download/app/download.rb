#!/usr/local/bin/ruby

require 'nokogiri'
require 'sony_ci_api'
require 'open-uri'


# s3 upload to OUTPUTBUCKET/OUTPUTFILENAME
def fail_job(job_uid, guid)
  puts "Oh no! Failing job..."
  `echo "Oops I did something bad! #{guid}" > ./donefile`
  # until runner starts looking for failures
  `aws s3api put-object --bucket lime-kaldi-output --key lime-kaldi-successes/#{job_uid}.txt --body ./donefile`
end

def succeed_job(job_uid, guid)
  puts "Succeeding job! Hooray!"
  `echo "Great Job! #{guid}" > ./donefile`
  `aws s3api put-object --bucket lime-kaldi-output --key lime-kaldi-successes/#{job_uid}.txt --body ./donefile`
end

def check_done
  # job first checks its its already done (after reboot)
  resp = `aws s3api head-object --bucket lime-kaldi-output --key lime-kaldi-successes/#{job_uid}.txt`
  !resp.empty?
end

# DOWNLOAD_GUID
# DOWNLOAD_OUTPUT_KEY (optional)
# DOWNLOAD_OUTPUT_BUCKET
job_uid = ENV["DOWNLOAD_UID"]
guid = ENV["DOWNLOAD_GUID"]
output_key = ENV["DOWNLOAD_OUTPUT_KEY"]
output_bucket = ENV["DOWNLOAD_OUTPUT_BUCKET"]
# if no GUID + OUTPUTBUCKET   --- fail

if check_done(job_uid)
  puts "Job is already complete! See you later!"
  return
end

unless guid && !guid.empty? && output_bucket && !output_bucket.empty?
  puts "missing params, failing job..."
  fail_job(job_uid)
  return
end

puts "Ok! Starting #{job_uid} work with GUID: #{guid}, Output Bucket: #{output_bucket}#{ output_key ? ", Output Key(opt): #{output_key}" : "" }"

# download aapb guid.pbcore
xml = `curl https://americanarchive.org/catalog/#{guid}.pbcore`
puts "Found XML of length #{xml.length}"

# get CI_ID from xml
doc = Nokogiri::XML(xml)
doc.remove_namespaces!
ci_node = doc.xpath( %(/*/pbcoreIdentifier[@source="Sony Ci"]) ).first
ci_id = ci_node.text if ci_node
puts "CI ID found #{ci_id}"

# make OUTPUTFILENAME
# form default output key if not specifieid
if !output_key
  ext = doc.xpath("/*/pbcoreInstantiation/instantiationMediaType").first == "Moving Image" ? "mp4" : "mp3"
  output_key = "#{guid}.#{ext}"

  puts "Output key is #{output_key}"
end

# where to download it to
local_path = %(/root/#{File.basename(output_key)})

# if DESTINATIONFILE already exists   --- fail (use succeed for the moment)
resp = `aws s3api head-object --bucket #{output_bucket} --key #{output_key}`
unless resp.empty?
  puts "destination file already exists, failing job..."
  fail_job(job_uid, guid) 
  return
end

# mounted secret on rancher
@client = SonyCiApi::Client.new( "/root/ci-config/ci-config.yml" )
File.open(local_path, "wb") do |f|
  url = @client.asset_download(ci_id)["location"]
  f.write( URI.open( url ) {|f| f.read } )
end

# upload file duh
`aws s3api put-object --bucket #{ output_bucket } --key #{output_key} --body #{ local_path }`

# success
puts "Great job! Marking success..."
succeed_job(job_uid, guid)
