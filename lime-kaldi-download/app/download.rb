#!/usr/local/bin/ruby

require 'nokogiri'
require 'sony_ci_api'

# DOWNLOAD_GUID
# DOWNLOAD_OUTPUT_KEY (optional)
# DOWNLOAD_OUTPUT_BUCKET
job_uid = ENV["DOWNLOAD_UID"]
guid = ENV["DOWNLOAD_GUID"]
output_key = ENV["DOWNLOAD_OUTPUT_KEY"]
output_bucket = ENV["DOWNLOAD_OUTPUT_BUCKET"]
# if no GUID + OUTPUTBUCKET   --- fail
unless guid && !guid.empty? && output_bucket && !output_bucket.empty?
  fail_job(job_uid)
end

# download aapb guid.pbcore
xml = `curl https://americanarchive.org/catalog/#{guid}.pbcore`

# get CI_ID from xml
doc = Nokogiri::XML(xml)
ci_id = doc.xpath("/*/pbcoreIdentifier[@source="Sony Ci"]").first

# where to download it to
local_path = %(/root/#{File.basename(output_key)})

# make OUTPUTFILENAME
# form default output key if not specifieid
if !output_key
  ext = doc.xpath("/*/pbcoreInstantiation/instantiationMediaType").first == "Moving Image" ? "mp4" : "mp3"
  output_key = "#{guid}.#{ext}"
end

# if DESTINATIONFILE already exists   --- fail (use succeed for the moment)
resp = `aws s3api head-object --bucket #{output_bucket} --key #{output_key}`
fail_job(job_uid) unless resp.empty?


# mounted secret on rancher
@client = SonyCiApi.new("/root/ci_credential")
File.open(local_path, "wb") do |f|
  f.write( open( @client.download(ci_id) ) {|g| g.read } )
end

# upload file duh
`aws s3api put-object --bucket #{output_bucket} --key #{output_key} --body ./#{ local_path }`

# success
succeed_job(job_uid)

# s3 upload to OUTPUTBUCKET/OUTPUTFILENAME
def fail_job(job_uid, guid)
  puts "Oh no! Failing job..."
  `echo 'Oops I did something bad! #{guid}' > ./#{job_uid}.txt`
  # until runner starts looking for failures
  `aws s3api put-object --bucket lime-kaldi-output --key lime-kaldi-successes/#{job_uid}`
end

def succeed_job(job_uid, guid)
  puts "Oh no! Failing job..."
  `echo "Great Job! #{guid}" > ./donefile`
  `aws s3api put-object --bucket lime-kaldi-output --key lime-kaldi-successes/#{job_uid}.txt --body ./donefile`
end

