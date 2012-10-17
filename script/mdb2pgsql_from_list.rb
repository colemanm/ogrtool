#!/usr/bin/env ruby

# Sample script for importing tables from personal geodatabases to a PostGIS database. Simple wrapper on ogrtool. Reads
#  a CSV file of layer names and geometry types, allowing you to cast from one geometry type to another. Read in a
#  buildings 'polygon' datasource and import as layer type 'multipolygon'.
#
# Usage: ./mdb2pgsql_from_list layers.txt
#   
# Example line in the CSV:
# buildings,MULTIPOLYGON

input_file = ARGV[0]

File.open("#{input_file}").each_line do |line|
  layer, nlt = line.strip.split(",")
  puts "Importing #{layer} as type #{nlt}..."
  `ogrtool topg -f file.mdb -l #{layer} -s src_srid -t dst_srid -d dbname -T #{nlt} -g geometry`
end