Simple bash script to classify photos based on exif data into dated directories (ex : 2010/06/27/img.jpg)

It will be smart enough not to overwrite files if already present, using a mixture of file size, ssdeep, md5 sigs and file name comparisons.