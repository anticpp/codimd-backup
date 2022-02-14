#!/usr/bin/ruby

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

# Constants
HACKMD_UPLOAD_DIR = "/home/hackmd/app/public/uploads/"
DUMP_DATABASE_FILENAME = "codimd_postgres.tar"
DUMP_UPLOAD_FILENAME = "codimd_upload.tar"
DUMP_DEFAULT_INTERVAL = 60*60

# Global
logger = Logger.new(STDOUT)

# Get env
cmd_db_url = getenv_or_exit('CMD_DB_URL')
dump_output_dir = getenv_or_exit('DUMP_OUTPUT_DIR')
dump_interval = getenv_or_default('DUMP_INTERVAL', DUMP_DEFAULT_INTERVAL).to_i

dump_database_file="#{dump_output_dir}/#{DUMP_DATABASE_FILENAME}"
dump_upload_file="#{dump_output_dir}/#{DUMP_UPLOAD_FILENAME}"

logger.info("cmd_db_url: " + cmd_db_url)
logger.info("dump_output_dir: " + dump_output_dir)
logger.info("dump_interval: %d"%(dump_interval))

# Main loop
last_t = Time.at(0)
now_t = Time.now
while true do
    now_t = Time.now
    eclapse = now_t.to_i - last_t.to_i
    next_interval = dump_interval-eclapse
    
    if next_interval>0 then
        logger.info(sprintf("next interval: %d seconds", next_interval))
        logger.info("sleep until: " + (now_t+next_interval).strftime("%Y-%m-%d %k:%M:%S"))
        sleep(next_interval)
        next
    end
    last_t = now_t
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
    zip_file=sprintf("%s/%s", dump_output_dir, now_t.strftime("%Y%m%d%k%M"))
    cmd="zip -m #{zip_file} #{dump_database_file} #{dump_upload_file}"
    !run_cmd(cmd) and next
end

# Upload to S3 storage
# TODO



