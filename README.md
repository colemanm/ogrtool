# ogrtool

**ogrtool** is a command line utility that wraps the `ogr2ogr` program for manipulating map data. It's built to make repetitive tasks simpler and easier to remember how to do (and to simplify automation). Don't take it too seriously, mostly makes my life as a non-programmer easier.

## Installation

First the template connections file your home directory:

```shell
cp postgres.yml.sample ~/.postgres
```

Here you can define custom Postgres database connections, so you don't have to pass them in everytime using raw `ogr2ogr`. Modify and add connection parameters for any of your Postgres servers.

Then install (defaults to `~/local/ogrtool`):

```shell
make
```

And add the location to your `PATH`.

## Usage

There are several different functions built into `ogrtool` to support common `org2ogr` operations:

* `topg` - Import datasets and layers into a PostGIS database.
* `clip` - Clip an area from a shapefile using a bounding box.
* `clip2shp` - Take a list of PostGIS layers and clips by bounding box to shapefiles.
* `features` - Get the feature count from file.
* `shproject` - Reproject shapefiles.
* `shpgeom` - Return the geometry type of a shapefile.