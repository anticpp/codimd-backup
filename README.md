codiMD backup
===========================
Backup codiMD periodically. 

## Workflow

1. Use `pg_dump` to dump postgresql database.
2. Tar codimd upload file to `tar`.
3. Zip together.

Dump to directory `/dumps/` every `86400 seconds(1 day)`, keep the most recent `10 backups`. You can change default behaviors via ENVs.

## ENVs

See [loop-dump.rb](https://github.com/anticpp/codimd-backup/blob/master/loop-dump.rb)

## Docker Hub

[supergui/codimd-backup](https://hub.docker.com/r/supergui/codimd-backup).

See `docker-run`.

## TODOs

- [X] Upload to S3 storage.
