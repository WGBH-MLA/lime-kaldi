# IMPORTANT :: For right now, you have to run crontab -e .. :wq on controller in order for crontab to take effect - then we get 2 work
# create jobs row with input_bucketname, input_filepath, status=0, cron will pick it up!
require 'mysql2'
require 'securerandom'
require 'json'
require 'pathname'

NUMBER_OF_QUEUES = 1

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

# exit if another copy of this script already running (took too long)
num_running = `ps aux| grep "queue-control.rb >> /var/log/queue-control.log 2>&1" | grep -v "/bin/sh" | grep -v grep | grep -v $$ | wc -l`
unless num_running.to_i == 1
  puts "Exiting, previous cron run still in progress... #{num_running}\n\n"
  return
end

# load db..
@client = Mysql2::Client.new(host: "lime-kaldi-mysql", username: "root", database: "limekaldi", password: "", port: 3306)

# def get_errortxt_filepath(uid)
#   # this is a folder of error files, marking the failure of a job, and containing the full stdout/err from the job itself
#   %(lime-kaldi-errors/error-#{uid}.txt)
# end

def get_donefile_filepath(uid)
  # this is a folder of empty files, marking the success of an audiosplit job
  %(lime-kaldi-successes/#{uid}.txt)
end

def get_failfile_filepath(uid)
  # this is a folder of empty files, marking the success of an audiosplit job
  %(lime-kaldi-failures/#{uid}.txt)
end

def get_pod_name(queue_number, uid)
  %(lime-kaldi-worker-#{ get_queue_label(queue_number) }-#{uid})
end

def set_job_status(uid, new_status, fail_reason=nil)
  puts "Setting job status for #{uid} to #{new_status}"
  if fail_reason
    # if we passed in a failure reason, save to db
    @client.query(%(UPDATE jobs SET status=#{new_status}, fail_reason="#{fail_reason}" WHERE uid="#{uid}"))
  else
    @client.query(%(UPDATE jobs SET status=#{new_status} WHERE uid="#{uid}"))
  end
end

def set_job_start_time(uid)
  @client.query(%(UPDATE jobs SET job_start_time="#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}" WHERE uid="#{uid}"))
end

def set_job_end_time(uid)
  @client.query(%(UPDATE jobs SET job_end_time="#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}" WHERE uid="#{uid}"))
end

def get_file_info(bucket, key)
 `aws s3api head-object --bucket #{bucket} --key #{key}`
end

def check_file_exists(bucket, file)
  s3_output = get_file_info(bucket, file)
  # ruby return value is "" for an s3 404
  s3_output && s3_output != ""
end

def get_queue_label(queue_number)
  "queue#{queue_number}"  
end

def begin_job(queue_number, uid, job_type, input_filepath, input_bucketname)
  # job = @client.query(%(SELECT * FROM jobs WHERE uid="#{uid}")).first
  # puts job.inspect
  # input_filepath = job["input_filepath"]
  # input_bucketname = job["input_bucketname"]

  fp = Pathname.new(input_filepath)
  input_folder = fp.dirname
  input_filename = fp.basename

  if job_type == JobType::CreateTranscript

    pod_yml_content = %{
apiVersion: v1
kind: Pod
metadata:
  name: lime-kaldi-worker-#{ get_queue_label(queue_number) }-#{uid}
  namespace: lime-kaldi
  labels:
    app: lime-kaldi-worker-#{ get_queue_label(queue_number) }
spec:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - lime-kaldi-worker-#{ get_queue_label(queue_number) }
        topologyKey: kubernetes.io/hostname
        
  volumes:
    - name: obstoresecrets
      secret:
        defaultMode: 256
        optional: false
        secretName: obstoresecrets
  containers:
    - name: lime-kaldi-worker
      image: foggbh/lime-kaldi-worker:latest
      resources:
        limits:
          memory: "9000Mi"
          cpu: "1200m"
      volumeMounts:
      - mountPath: /root/.aws
        name: obstoresecrets
        readOnly: true
      env:
      - name: LIMEKALDI_UID
        value: #{uid}
      - name: LIMEKALDI_INPUT_BUCKET
        value: #{ input_bucketname }
      - name: LIMEKALDI_INPUT_KEY
        value: #{ input_filepath }
      - name: LIMEKALDI_OUTPUT_BUCKET
        value: lime-kaldi-output
  imagePullSecrets:
      - name: mla-dockerhub
  }

elsif job_type == JobType::DownloadFromCi

    pod_yml_content = %{
apiVersion: v1
kind: Pod
metadata:
  name: lime-kaldi-worker-#{ get_queue_label(queue_number) }-#{uid}
  namespace: lime-kaldi
  labels:
    app: lime-kaldi-worker-#{ get_queue_label(queue_number) }
spec:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - lime-kaldi-worker-#{ get_queue_label(queue_number) }
        topologyKey: kubernetes.io/hostname
        
  volumes:
    - name: obstoresecrets
      secret:
        defaultMode: 256
        optional: false
        secretName: obstoresecrets
    - name: ci-config
      secret:
        defaultMode: 256
        optional: false
        secretName: ci-config        
  containers:
    - name: lime-kaldi-worker
      image: foggbh/lime-kaldi-download:latest
      resources:
        limits:
          memory: "9000Mi"
          cpu: "1200m"
      volumeMounts:
      - mountPath: /root/.aws
        name: obstoresecrets
        readOnly: true
      - mountPath: /root/ci-config
        name: ci-config
        readOnly: true
      env:
      - name: DOWNLOAD_UID
        value: #{uid}
      - name: DOWNLOAD_GUID
        value: #{ input_filepath }
      - name: DOWNLOAD_OUTPUT_BUCKET
        value: lime-kaldi-input
  imagePullSecrets:
      - name: mla-dockerhub
  }
  end

      # not included for now
      # - name: DOWNLOAD_OUTPUT_KEY
      #   value: #{ input_filepath }

  # if you need to ensure that newest is coming through from docker hub
    # - name: lime-kaldi-worker
    #   image: foggbh/lime-kaldi-download:latest
    #   imagePullPolicy: Always

  File.open('/root/pod.yml', 'w+') do |f|
    f << pod_yml_content
  end

  puts "I sure would like to start #{uid} for #{input_filename}!"
  puts `kubectl --kubeconfig /mnt/kubectl-secret --namespace=lime-kaldi apply -f /root/pod.yml`
  set_job_status(uid, JobStatus::Working)
  set_job_start_time(uid)
end


NUMBER_OF_QUEUES.times do |queue_number|

  jobs = @client.query("SELECT * FROM jobs WHERE queue_number=#{ queue_number } AND status=#{JobStatus::New} LIMIT 24")
  # actually start jobs that we successfully initted above - limit 48 so we dont ask 'how many pods' a thousand times every cycle, but have enough of a buffer to get 4 new pods for any issues talking to kube  puts "Found #{jobs.count} jobs with JS::New"
  
  jobs.each do |job|

    # check how many workers in this queue only
    num_lime_workers = `/root/app/check_number_pods.sh #{ get_queue_label(queue_number) }`

    if num_lime_workers.to_i == -1
      puts "Failed to grab number of pods due to TLS error... skipping starting job on #{job["uid"]} this time around"
      next
    end

    puts "There are #{num_lime_workers} running right now..."
    if num_lime_workers.to_i < 4

      puts "Ooh yeah - I'm starting #{job["uid"]}!"
      begin_job(job["queue_number"], job["uid"], job["job_type"], job["input_filepath"], job["input_bucketname"])
    end
  end
end

# check if file Status::WORKING exists on objectstore, mark as completedWork if done...
# job.each...
jobs = @client.query("SELECT * FROM jobs WHERE status=#{ JobStatus::Working }")
puts "Found #{jobs.count} jobs with JS::Working"

jobs.each do |job|
  job_failed = false
  puts "Found JS::Working job #{job.inspect}, checking pod #{job["uid"]}"

  donefilepath = get_donefile_filepath(job["uid"])
  failfilepath = get_failfile_filepath(job["uid"])
  
  if job["job_type"] == JobType::CreateTranscript

    puts "CreateTranscript CHECK:: Now searching for Fail file #{failfilepath}"
    resp = `aws s3api head-object --bucket lime-kaldi-output --key #{failfilepath}`
    # if done file is present, work completed successfully
    job_finished = !resp.empty?
    
    if job_finished
      puts "Fail! File #{job["uid"]} was found on object store" if job_finished
      job_failed = true
  
    else
      puts "CreateTranscript CHECK:: Now searching for Done file #{donefilepath}"
      resp = `aws s3api head-object --bucket lime-kaldi-output --key #{donefilepath}`
      # if done file is present, work completed successfully
      job_finished = !resp.empty?
      puts "Done File #{job["uid"]} was found on object store" if job_finished
    end

  elsif job["job_type"] == JobType::DownloadFromCi

    puts "CreateTranscript CHECK:: Now searching for Fail file #{failfilepath}"
    resp = `aws s3api head-object --bucket lime-kaldi-output --key #{failfilepath}`
    # if done file is present, work completed successfully
    job_finished = !resp.empty?
    
    if job_finished
      puts "Fail! File #{job["uid"]} was found on object store" if job_finished
      job_failed = true

    else
      puts "DownloadFromCi CHECK:: Now searching for Done file #{donefilepath}"
      resp = `aws s3api head-object --bucket lime-kaldi-output --key #{donefilepath}`
      # if done file is present, work completed successfully
      job_finished = !resp.empty?
      puts "Done File #{job["uid"]} was found on object store" if job_finished
    end
  end

  puts "Got OBSTORE response #{resp} for #{job["uid"]} in Queue #{job["queue_number"]}"

  pod_name = get_pod_name(job["queue_number"], job["uid"])
  # (now this is pod naming)

  if job_finished
    # head-object returns "" in this context when 404, otherwise gives a zesty pan-fried json message as a String
    puts "Job Succeeded - Attempting to delete pod #{pod_name}"
    puts `kubectl --kubeconfig=/mnt/kubectl-secret --namespace=lime-kaldi delete pod #{pod_name}`  

    if job_failed

      # can use the fail file contents to set the error msg later
      if job["job_type"] == JobType::CreateTranscript
        set_job_status(job["uid"], JobStatus::Fail, "Existing TS file was found in AAPB bucket")
      elsif job["job_type"] == JobType::DownloadFromCi
        set_job_status(job["uid"], JobStatus::Fail, "Could not download from CI sowwy")
      end
    else
      set_job_status(job["uid"], JobStatus::Done)
      set_job_end_time(job["uid"])
    end
  else

    # TODO: add this back into worker

    # # check for error file...
    # puts "Checking for error file on #{job["uid"]}"
    # errortxt_filepath = get_errortxt_filepath(job["uid"])
    # resp = `aws --endpoint-url 'http://s3-bos.wgbh.org' s3api head-object --bucket streaming-proxies --key #{errortxt_filepath}`

    # # error file was found
    # if !resp.empty?
    #   puts "Error detected on #{job["uid"]}, Going to kill container :("
    #   puts `kubectl --kubeconfig=/mnt/kubectl-secret --namespace=lime-kaldi delete pod #{pod_name}`  
    #   set_job_status(job["uid"], JobStatus::Failed, "Error file was found, failing")
    # else 
    #   puts "Job #{job["uid"]} isnt done, keeeeeeeep going!"
    # end
  end
end

# CREATE TABLE jobs (uid varchar(255), status int, input_filepath varchar(1024), fail_reason varchar(1024), created_at datetime DEFAULT CURRENT_TIMESTAMP, job_type int DEFAULT 0, input_bucketname varchar(1024), queue_number int DEFAULT 0, job_start_time datetime, job_end_time datetime);

# moving car
# ALTER TABLE jobs ADD COLUMN job_type int DEFAULT 0
# ALTER TABLE jobs ADD COLUMN created_at datetime DEFAULT CURRENT_TIMESTAMP

# ALTER TABLE jobs ADD COLUMN input_bucketname varchar(1024);

# ALTER TABLE jobs ADD COLUMN queue_number int DEFAULT 0;

# ALTER TABLE jobs ADD COLUMN job_start_time datetime;
# ALTER TABLE jobs ADD COLUMN job_end_time datetime;

# CREATE TABLE next_queue_number (number int DEFAULT 0);

