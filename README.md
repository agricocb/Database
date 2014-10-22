Database
========

A repository for the curation of the database with information about trails and
POIs

Running make on the command line on a UNIX like machine (I've only tried it on
Linux and MacOSX) should download and build the tools needed to convert the
Shapefile data in MillstoneTrailsData.zip to a KML file.  Then it will unpack
the Shapefile data and do the conversion, after which it will run the
kml_to_sqlite.pl script.

The kml_to_sqlite.pl script is a Perl script to parse the KML file and load it
into a SQLite3 database after creating the schema for the database, which is at
the bottom of the script.

Both the generated MillstoneTrails.kml and the BarreForestGuide.sqlite files
are checked in as resulting from a run on my Linux machine.  When I run it on a
MacOSX machine, one of the coordinates (out of thousands), seems to have a
rounding error (not sure if the Linux machine or the OSX machine is the one
that is wrong), but I think they are both close enough that it won't matter.
