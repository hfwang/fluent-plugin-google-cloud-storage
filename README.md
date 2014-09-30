# fluent-plugin-google-cloud-storage

[Fluentd](http://fluentd.org/) output plugin to write data into a [Google Cloud
Storage](https://cloud.google.com/storage/) bucket.

GoogleCloudStorageOutput slices data by time (specified unit), and store these
data as file of plain text. You can specify to:

* format whole data as serialized JSON, single attribute or separated multi attributes
* or LTSV, labeled-TSV (see http://ltsv.org/ )
* include time as line header, or not
* include tag as line header, or not
* change field separator (default: TAB)
* add new line as termination, or not

And you can specify output file path as 'path path/to/dir/access.%Y%m%d.log', then get 'path/to/dir/access.20120316.log' in your GCS bucket.

## Configuration

### GoogleCloudStorageOutput

To store data by time,tag,json (same with 'type file') over WebHDFS:

    <match access.**>
      type google_cloud_storage
      service_email SERVICE_ACCOUNT_EMAIL
      service_pkcs12_path /path/to/key.p12
      project_id name-of-project
      bucket_id name-of-bucket
      path path/to/access.%Y%m%d_%H.log
    </match>

To specify the pkcs12 file's password, use `service_pkcs12_password`:

    <match access.**>
      type google_cloud_storage
      service_email SERVICE_ACCOUNT_EMAIL
      service_pkcs12_path /path/to/key.p12
      service_pkcs12_password SECRET_PASSWORD
      project_id name-of-project
      bucket_id name-of-bucket
      path path/to/access.%Y%m%d_%H.log
    </match>

If you want JSON object only (without time or tag or both on header of lines), specify it by `output_include_time` or `output_include_tag` (default true):

    <match access.**>
      type google_cloud_storage
      service_email SERVICE_ACCOUNT_EMAIL
      service_pkcs12_path /path/to/key.p12
      project_id name-of-project
      bucket_id name-of-bucket
      path path/to/access.%Y%m%d_%H.log
      output_include_time false
      output_include_tag  false
    </match>

To store data as LTSV without time and tag over WebHDFS:

    <match access.**>
      type google_cloud_storage
      # ...
      output_data_type ltsv
    </match>

Store data as TSV (TAB separated values) of specified keys, without time, with tag (removed prefix 'access'):

    <match access.**>
      type google_cloud_storage
      # ...

      field_separator TAB        # or 'SPACE', 'COMMA' or 'SOH'(Start Of Heading: \001)
      output_include_time false
      output_include_tag true
      remove_prefix access

      output_data_type attr:path,status,referer,agent,bytes
    </match>

If message doesn't have specified attribute, fluent-plugin-webhdfs outputs 'NULL' instead of values.

To store data compressed (gzip only now):

    <match access.**>
      type google_cloud_storage
      # ...

      compress gzip
    </match>

### Performance notifications

As GCS does not support appending to files, if you have multiple fluentd nodes,
you most likely want to log to multiple files. You can use '${hostname}' or
'${uuid:random}' placeholders in configuration for this purpose.

For hostname:

    <match access.**>
      type google_cloud_storage
      # ...
      path log/access/%Y%m%d/${hostname}.log
    </match>

Or with random filename (to avoid duplicated file name only):

    <match access.**>
      type google_cloud_storage
      # ...
      path log/access/%Y%m%d/${uuid:random}.log
    </match>

With configurations above, you can handle all of files of '/log/access/20120820/*' as specified timeslice access logs.

## TODO

* docs?
* patches welcome!

## Copyright

* Copyright (c) 2014- Hsiu-Fan Wang (hfwang@porkbuns.net)
* License
  * Apache License, Version 2.0
