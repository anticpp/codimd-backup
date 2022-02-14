codiMD backup
===========================
Backup codiMD internally. 

## Workflow

1. Use `pg_dump` to dump postgresql database to `tar`.
2. Tar codimd upload file to `tar`.
3. Zip together.


## ENVs

- `CMD_DB_URL`="postgres://codimd:password123@database/codimd"
- `DUMP_INTERVAL`=60
- `DUMP_OUTPUT_DIR`=/app/dumps/

## TODOs

- Upload to S3 storage
