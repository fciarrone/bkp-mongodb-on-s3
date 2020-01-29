#!/bin/bash

## Developed by Fabio Ciarrone

#---

#Database host
db_name_host="database_host"
#Local folder to create mysqldump
db_path_to_dump="/mongodump/database_bkp_folder"
#S3 storage destination
s3_bkp_bucket="s3://bucket/folder"
#Timestamp
timestamp=$(date +%Y-%m-%d_%Hh%Mm%Ss)
# How many days should we keep the backups on Amazon before deletion?
daystokeep="14"
# Delete old backups? Any files older than $daystokeep will be deleted on the bucket
# Don't use this option on buckets which you use for other purposes as well
# Default option     : 0
# Recommended option : 1
purgeoldbackups="1"

#---

echo -e "Starting backup" $(date +%Y-%m-%d\ %H:%M:%S) "\n"

mongodump --host ${db_name_host} --out ${db_path_to_dump}

for i in ${db_path_to_dump}/* ;
do
    7z a "${i}_${timestamp}.7z" ${i};
    /usr/bin/s3cmd put ${i}_${timestamp}.7z ${s3_bkp_bucket}/;
done;

rm -rf -v ${db_path_to_dump}/*

# Clean old files
if [[ "$purgeoldbackups" -eq "1" ]]
then
    echo -e " \e[1;35mRemoving old backups...\e[00m"
    olderThan=`date -d "$daystokeep days ago" +%s`

    /usr/bin/s3cmd --recursive ls $s3_bkp_bucket | while read -r line;
    do
        createDate=`echo $line|awk {'print $1" "$2'}`
        createDate=`date -d"$createDate" +%s`
        if [[ $createDate -lt $olderThan ]]
        then 
            fileName=`echo $line|awk {'print $4'}`
            echo -e " Removing outdated backup \e[1;31m$fileName\e[00m"
            if [[ $fileName != "" ]]
            then
                /usr/bin/s3cmd del "$fileName"
            fi
        fi
    done;
fi

echo -e "Backup finished" $(date +%Y-%m-%d\ %H:%M:%S) "\n"

