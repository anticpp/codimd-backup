#!/usr/bin/ruby
#
# ENVs:
#   -------------------------------------------------------------------------------------------------------------------
#   |      Name              | Required?  | Default value |           Intro                                           |
#   -------------------------------------------------------------------------------------------------------------------
#   | CMD_DB_URL             |   YES      |    ""         | "postgres://codimd:password123@database/codimd"           |
#   -------------------------------------------------------------------------------------------------------------------
#   | DUMP_INTERVAL          |   NOT      |    86400      | Seconds                                                   |
#   -------------------------------------------------------------------------------------------------------------------
#   | DUMP_OUTPUT_DIR        |   NOT      |    /dumps/    |                                                           |
#   -------------------------------------------------------------------------------------------------------------------
#   | MAX_BACKUPS            |   NOT      |    10         | Keep the most recent backups,                             |
#   |                        |            |               | old ones will be deleted.                                 |
#   -------------------------------------------------------------------------------------------------------------------
#   | CLOUD_STORAGE_DSN      |   NOT      |    ""         | Specify cloud storage to upload backups.                  |
#   |                        |            |               | Format:                                                   |
#   |                        |            |               |  "aliyun://${KEYID}:${KEYSECRET}@${ENDPOINT}/${BUCKET}"   |
#   -------------------------------------------------------------------------------------------------------------------
#


require "logger"
require_relative "aliyun/oss"

# Functions
def run_cmd(cmd)
    logger = Logger.new(STDOUT)
    logger.info(cmd)
    !system(cmd) and logger.error("Run cmd fail: \"" + cmd + "\"") and return false
    return true
end

def getenv_or_default(name, default)
    v=ENV[name]
    if v then
        return v
    end
    return default
end

def getenv_or_exit(name)
    logger = Logger.new(STDOUT)
    v=ENV[name]
    if !v then
        logger.error("#{name} env is required.")
        exit
    end
    return v
end

def true?(obj) 
  obj.to_s.downcase == "true"
end

# Try load lasttime from cachefile.
# If fail, return time at 0.
def try_load_lasttime(cachefile)
  logger = Logger.new(STDOUT)
  begin
    f = File.open(cachefile)
    ts = f.read()
    f.close
  rescue
    return Time.at(0)
  end
  lt = Time.at(ts.to_i)
  logger.info(sprintf("load lasttime from cachefile: %s", lt.strftime("%Y-%m-%d %k:%M:%S")))
  return lt
end

def flush_lasttime(cachefile, ts)
  begin
    File.write(cachefile, ts.to_i)
  rescue
    return false
  end
  return true
end

# Constants
HACKMD_UPLOAD_DIR = "/home/hackmd/app/public/uploads/"
DUMP_DATABASE_FILENAME = "codimd_postgres.tar"
DUMP_UPLOAD_FILENAME = "codimd_upload.tar"
DEFAULT_DUMP_INTERVAL = 60*60*24
DEFAULT_MAX_BACKUPS = 10
TSCACHE_FILENAME = ".ts.cache"

## "aliyun://${KEYID}:${KEYSECRET}@${ENDPOINT}/${BUCKET}"
CS_DSN_PATTERN = /aliyun\:\/\/([\w=]*)\:([\w=]*)\@([\w\-\._]*)\/([\w\-_]*)/ 

# Global
logger = Logger.new(STDOUT)

# Get env
cmd_db_url = getenv_or_exit('CMD_DB_URL')
dump_output_dir = getenv_or_default('DUMP_OUTPUT_DIR', "/dumps/")
dump_interval = getenv_or_default('DUMP_INTERVAL', DEFAULT_DUMP_INTERVAL).to_i
max_backups = getenv_or_default('MAX_BACKUPS', DEFAULT_MAX_BACKUPS).to_i

dump_database_file="#{dump_output_dir}/#{DUMP_DATABASE_FILENAME}"
dump_upload_file="#{dump_output_dir}/#{DUMP_UPLOAD_FILENAME}"
tscache_file="#{dump_output_dir}/#{TSCACHE_FILENAME}"

# Cloud storage
cs_on = false
cs_dsn = ""
cs_access_key_id = ""
cs_access_key_secret = ""
cs_endpoint = ""
cs_bucket_name = ""

cs_dsn = getenv_or_default("CLOUD_STORAGE_DSN", "")
if !cs_dsn.empty? then
  if ! CS_DSN_PATTERN =~ cs_dsn then
    logger.error("CLOUD_STORAGE_DSN error: #{CLOUD_STORAGE_DSN}")
    logger.error("PATTERN: #{CS_DSN_PATTERN}")
    logger.error("Please check your DSN, example: \"aliyun://abc:def@oss/yyyy\". ")
  else
    cs_on = true
    regd = Regexp.last_match
    cs_access_key_id, cs_access_key_secret, cs_endpoint, cs_bucket_name = regd[1], regd[2], regd[3], regd[4]
  end
end

logger.info("cmd_db_url: " + cmd_db_url)
logger.info("dump_output_dir: " + dump_output_dir)
logger.info("dump_interval: %d"%(dump_interval))
logger.info("max_backups: %d"%(max_backups))

if cs_on then
  logger.info("Cloud storage is ON.")
  logger.info("Access_key_id: #{cs_access_key_id}, access_key_secret: #{cs_access_key_secret}, bucket_name: #{bucket_name}")
else
  logger.info("Cloud storage is OFF.")
end

# Load lasttime from cache
last_t = try_load_lasttime(tscache_file)
now_t = Time.now

## last time is error, set to 0
if last_t.to_i>now_t.to_i then
  last_t = Time.at(0)
end

# Main loop
while true do
    now_t = Time.now
    eclapse = now_t.to_i - last_t.to_i
    next_interval = dump_interval-eclapse
    
    if next_interval>0 then
        logger.info(sprintf("next interval: %d seconds", next_interval))
        logger.info("sleep until: " + (now_t+next_interval).strftime("%Y-%m-%d %k:%M:%S"))
        STDOUT.flush
        sleep(next_interval)
        next
    end
    last_t = now_t
    flush_lasttime(tscache_file, last_t)
    logger.info("Run dump now")

    # Dump postgres database
    logger.info("dump database ...")
    cmd = "pg_dump --dbname=#{cmd_db_url} -F t -f #{dump_database_file}"
    !run_cmd(cmd) and next

    # Dump uploads
    logger.info("tar upload ...")
    cmd = "tar -zcvf #{dump_upload_file} -C #{HACKMD_UPLOAD_DIR} ."
    !run_cmd(cmd) and next

    # Zip together
    zip_filename = sprintf("codimd_%s", now_t.strftime("%Y%02m%02d%02k%02M"))
    zip_filepath = "#{dump_output_dir}/#{zip_filename}"
    cmd="zip -m #{zip_file} #{dump_database_file} #{dump_upload_file}"
    !run_cmd(cmd) and next

    # Remove oldest backups
    Dir.glob(dump_output_dir+"/codimd_*.zip").sort_by { |f|
      File.mtime(f)
    }.reverse.each.with_index { |f, n|
      if n<max_backups then
        next
      end
      logger.info("Removing old backup "+f)
      File.delete(f)
    }

    # Upload to cloud storage
    if cs_on then
      logger.info("Uploading to cloud storage: #{cs_endpoint}")

      client = Aliyun::OSS::Client.new(cs_endpoint,
                cs_access_key_id,
                cs_access_key_secret)

      t0 = time.now
      client.put_object_from_file(cs_bucket_name, zip_filename, zip_filepath) { |err, message|
        t1 = time.now
        if err!=Aliyun::OSS::OK then
          logger.error("Upload error: #{err}, message: #{message}"
        else
          logger.info("Success")
          logger.info("Eclapse: #{t1-t0} seconds")
        end
      }

    end
end




