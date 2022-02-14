codiMD backup
===========================
Backup codiMD internally. 

## Workflow

1. Use `pg_dump` to dump postgresql database.
2. Tar codimd upload file to `tar`.
3. Zip together.

## ENVs

See [loop-dump.rb](https://github.com/anticpp/codimd-backup/blob/master/loop-dump.rb)

## docker-compose

[supergui/codimd-backup](https://hub.docker.com/r/supergui/codimd-backup)

## TODOs

- Upload to S3 storage
