#!/usr/bin/env ruby

require 'rubygems'
require 'thor'
require 'yaml'

# A tool for performing simple tasks with OGR.

class OgrTool < Thor

  desc "info", "Show info summary about dataset."
  method_option :file, :aliases => "-f", :desc => "File from which to show info."
  def info
    `ogrinfo -so -al #{options[:file]}`
  end

  desc "clip", "Clip an area from a shapefile. Use 'x_min y_min x_max y_max' notation to define the bounding box."
  method_option :bbox, :aliases => '-b', :desc => "Define the bounding area (e.g. \"498438 395921 566498 471747\" in dataset units)", :required => true
  method_option :file, :aliases => '-f', :desc => "File to clip an area from", :required => true
  def clip
    input_file = options[:file]
    output_file = "#{File.join(File.dirname(options[:file]), File.basename(options[:file], File.extname(options[:file])))}_clip.shp"
    bb = options[:bbox]
    `ogr2ogr -f "ESRI Shapefile" #{output_file} #{input_file} -clipsrc #{bb}`
  end

  desc "clip2shp", "Takes a list of PostGIS layers and clips by bounding area to shapefiles."
  method_option :bbox, :aliases => '-b', :desc => "Define the bounding area (e.g. \"498438 395921 566498 471747\")", :required => true
  method_option :list, :aliases => '-l', :desc => "List of layer names to export as shapefiles", :required => true
  method_option :host, :aliases => '-h', :desc => "Database server hostname"
  method_option :user, :aliases => '-u', :desc => "Username to connect to database"
  method_option :dbname, :aliases => '-d', :desc => "PostGIS database to connect to"
  method_option :port, :aliases => '-p', :desc => "PostgreSQL server port number"
  def clip2shp
    bb = options[:bbox]
    File.open("#{options[:list]}").each_line do |line|
      layer = line.strip
      `ogr2ogr -f "ESRI Shapefile" #{layer}.shp PG:"#{db_config(options)}" #{layer} -clipsrc #{bb} -lco ENCODING=UTF-8`
    end
  end

  desc "topg", "Import a GIS data file into PostGIS."
  method_option :file, :aliases => '-f', :desc => "File to import", :required => true
  method_option :layer, :aliases => '-l', :desc => "Layer name to import"
  method_option :connection, :aliases => '-c', :desc => "Connection name (defined in ~/.postgres)", :default => 'localhost'
  method_option :append, :aliases => '-A', :desc => "Append to existing data table"
  method_option :source, :aliases => '-s', :desc => "Source SRID to convert from"
  method_option :transform, :aliases => '-t', :desc => "Destination SRID to tranform to"
  method_option :assign, :aliases => '-a', :desc => "Assign this SRID on table creation"
  method_option :dbname, :aliases => '-d', :desc => "PostGIS database to connect to"
  method_option :nln, :aliases => '-n', :desc => "Destination layer name (can include schema, e.g. 'schema.layername')"
  method_option :encoding, :aliases => '-e', :desc => "Specify client encoding (e.g. latin1, UTF8, cp936, etc.)", :default => "UTF-8"
  method_option :type, :aliases => '-T', :desc => "Cast to a new layer type, such as multipolygon or multilinestring"
  method_option :geometry, :aliases => '-g', :desc => "Set a custom geometry column name"
  method_option :overwrite, :aliases => '-O', :desc => "Overwrite current layer(s)", :type => :boolean
  method_option :skipfailures, :aliases => '-S', :desc => "Skip failed row imports", :type => :boolean
  def topg
    layer = options[:layer] if options[:layer]
    nlt = "-nlt #{options[:type]}" if options[:type]
    nln = "-nln #{options[:nln]}" if options[:nln]
    lco = "-lco GEOMETRY_NAME=#{options[:geometry]}" if options[:geometry]
    append = "-append" if options[:append]
    srid_params = []
      srid_params << "-s_srs EPSG:#{options[:source]}" if options[:source]
      srid_params << "-t_srs EPSG:#{options[:transform]}" if options[:transform]
      srid_params << "-a_srs EPSG:#{options[:assign]}" if options[:assign]
      srid_params = srid_params.join(' ')
    overwrite = "-overwrite" if options[:overwrite]
    skipfailures = "-skipfailures" if options[:skipfailures]
    `ogr2ogr -f "PostgreSQL" #{srid_params} PG:"#{db_config(options)}" #{options[:file]} #{layer} #{nlt} #{nln} #{lco} #{overwrite} #{append} #{skipfailures}`
  end

  desc "shproject", "Reproject a shapefile using source and destination SRS EPSG codes."
  method_option :inputfile, :aliases => '-f', :desc => "File to reproject", :required => true
  method_option :source, :aliases => '-s', :desc => "Source data SRS"
  method_option :transform, :aliases => '-t', :desc => "Destination data SRS"
  method_option :assign, :aliases => '-a', :desc => "Assign data SRS"
  def shproject
    input_file = options[:inputfile]
    output_file = "#{File.join(File.dirname(options[:inputfile]), File.basename(options[:inputfile], File.extname(options[:inputfile])))}_project.shp"
    `ogr2ogr -f "ESRI Shapefile" #{srid_params(options)} #{output_file} #{input_file}`
  end

  desc "features", "Get the feature count from a file."
  method_option :file, :aliases => '-f', :desc => "File to count features from", :required => true
  method_option :layer, :aliases => '-l', :desc => "Layer name"
  def features
    puts `ogrinfo -so -al #{options[:file]} #{options[:layer]} | grep -w "Feature Count" | sed 's/Feature Count: //g'`
  end

  desc "shpgeom", "Get the geometry type for a file."
  method_option :file, :aliases => '-f', :desc => "File to get geometry from"
  method_option :list, :aliases => '-l', :desc => "List of shapefiles to parse (file.shp on each line)"
  def shpgeom
    file = options[:file]
    if options[:file]
      puts `ogrinfo -so #{file} #{basename} | grep -w Geometry | sed 's/Geometry: //g'`
    elsif options[:list]
      File.open("#{options[:list]}").each_line do |line|
        line.strip!
        puts `ogrinfo -so -al #{line} | grep -w Geometry | sed 's/Geometry: /#{line}: /g'`
      end
    end
  end

  no_tasks do
    def db_config(options)
      config = YAML.load(File.read(File.expand_path('~/.postgres')))[options[:connection]]
      config.merge!({
        'dbname' => options[:dbname],
        'options'   => "'-c client_encoding=#{options[:encoding]}'"
      }.reject{|k,v| v.nil?})
      config.reject{|k,v| v.nil?}.map{ |k,v| "#{k}=#{v}" }.join(' ')
    end

    def srid_params(options)
      srid_params = []
      srid_params << "-s_srs EPSG:#{options[:source]}" if options[:source]
      srid_params << "-t_srs EPSG:#{options[:transform]}" if options[:transform]
      srid_params << "-a_srs EPSG:#{options[:assign]}" if options[:assign]
      srid_params = srid_params.join(' ')
    end
  end

end

OgrTool.start