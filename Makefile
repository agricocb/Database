GDAL_CONFIG=--with-ogr --without-libtool --with-libz=internal \
	    --with-libtiff=internal --with-geotiff=internal --without-liblzma \
	    --without-pg --without-grass --without-libgrass --without-cfitsio \
	    --without-pcraster --without-png --without-dds --without-gta \
	    --without-pcidsk --without-jpeg --without-gif --without-ogdi \
	    --without-fme --without-sosi --without-hdf4 --without-hdf5 \
	    --without-netcdf --without-jasper --without-openjpeg --without-fgdb\
	    --without-ecw --without-kakadu --without-mrsid --without-jp2mrsid \
	    --without-mrsid_lidar --without-msg --without-oci --without-mysql \
	    --without-ingres --without-xerces --without-expat --without-odbc \
	    --without-dods-root --without-curl --without-xml2 \
	    --without-spatialite --without-sqlite3 --without-pcre \
	    --without-dwgdirect --without-dwg-plt --without-idb --without-sde \
	    --without-sde-version --without-epsilon --without-webp \
	    --without-geos --without-opencl --without-freexl --without-poppler \
	    --without-podofo --without-gdal-ver --without-macosx-framework \
	    --without-perl --without-php --without-ruby --without-python \
	    --without-java --without-mdb --without-jvm-lib \
	    --without-jvm-lib-add-rpath --without-rasdaman --without-armadillo \
	    --without-grib
GDAL=$(PWD)/gdal

all: BarreForestGuide.sqlite

gdal-1.11.1.tar.gz:
	curl -O "http://download.osgeo.org/gdal/1.11.1/gdal-1.11.1.tar.gz"

proj-4.8.0.tar.gz:
	curl -O "http://download.osgeo.org/proj/proj-4.8.0.tar.gz"

$(GDAL)/bin/ogr2ogr: gdal-1.11.1.tar.gz proj-4.8.0.tar.gz
	tar -xvzf proj-4.8.0.tar.gz
	(cd proj-4.8.0; ./configure --prefix=$(GDAL) && make && make install)
	rm -rf proj-4.8.0
	tar -xvzf gdal-1.11.1.tar.gz
	(cd gdal-1.11.1; ./configure --prefix=$(GDAL) $(GDAL_CONFIG) && make \
		&& make install)
	rm -rf gdal-1.11.1

MillstoneTrails.kml: MillstoneTrailsData.zip $(GDAL)/bin/ogr2ogr
	unzip MillstoneTrailsData.zip
	(LD_LIBRARY_PATH=$(GDAL)/lib DYLD_LIBRARY_PATH=$(GDAL)/lib $(GDAL)/bin/ogr2ogr -f KML $@ MillstoneTrails/Trails_polyline.shp)
	rm -r MillstoneTrails

BTF_disc.kml: disc_golf.zip $(GDAL)/bin/ogr2ogr
	unzip -j -d disc_golf disc_golf.zip
	cp disc_golf/BTF_disc.prj disc_golf/Teebox\ long.prj
	cp disc_golf/BTF_disc.prj disc_golf/Teebox\ short.prj
	cp disc_golf/Teebox\ long.dbf disc_golf/Teebox\ short.dbf
	(LD_LIBRARY_PATH=$(GDAL)/lib DYLD_LIBRARY_PATH=$(GDAL)/lib $(GDAL)/bin/ogr2ogr -f KML $@ disc_golf/BTF_disc.shp)
	(LD_LIBRARY_PATH=$(GDAL)/lib DYLD_LIBRARY_PATH=$(GDAL)/lib $(GDAL)/bin/ogr2ogr -f KML Teebox_long.kml disc_golf/Teebox\ long.shp)
	(LD_LIBRARY_PATH=$(GDAL)/lib DYLD_LIBRARY_PATH=$(GDAL)/lib $(GDAL)/bin/ogr2ogr -f KML Teebox_short.kml disc_golf/Teebox\ short.shp)
	rm -r disc_golf

BarreForestGuide.sqlite: MillstoneTrails.kml BTF_disc.kml Teebox_long.kml Teebox_short.kml kml_to_sqlite.pl
	./kml_to_sqlite.pl

clean:
	rm -f gdal-1.11.1.tar.gz
	rm -f proj-4.8.0.tar.gz
	rm -rf $(GDAL)
	rm -f MillstoneTrails.kml
	rm -f BTF_disc.kml Teebox_long.kml Teebox_short.kml

distclean: clean
	rm -f BarreForestGuide.sqlite
