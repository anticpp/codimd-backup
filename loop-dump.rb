#!/usr/bin/ruby
#
# ENVs:
#   - `CMD_DB_URL`         - Required
#      Example: "postgres://codimd:password123@database/codimd"
#   - `DUMP_INTERVAL`     - NOT Required
#      Default 86400 (1day)
#   - `DUMP_OUTPUT_DIR    - NOT Required
#      Default '/dumps/'
#   - `MAX_BACKUPS        - NOT Required
#      Default 10
#

require "logger"

# Functions
def run_cmd(cmd)
    logger = Logger.new(STDOUT)
    logger.info(cmd)
    !system(cmd) and logger.error("Run cmd fail: \"" + cmd + "\"") and return false
    return true
end

def getenv_or_default(name, default)
    logger = Logger.new(STDOUT)
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

logger.info("cmd_db_url: " + cmd_db_url)
logger.info("dump_output_dir: " + dump_output_dir)
logger.info("dump_interval: %d"%(dump_interval))
logger.info("max_backups: %d"%(max_backups))

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
    cmd="pg_dump --dbname=#{cmd_db_url} -F t -f #{dump_database_file}"
    !run_cmd(cmd) and next

    # Dump uploads
    logger.info("tar upload ...")
    cmd="tar -zcvf #{dump_upload_file} -C #{HACKMD_UPLOAD_DIR} ."
    !run_cmd(cmd) and next

    # Zip together
    zip_file=sprintf("%s/codimd_%s", dump_output_dir, now_t.strftime("%Y%02m%02d%02k%02M"))
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
end

# Upload to S3 storage
# TODO



