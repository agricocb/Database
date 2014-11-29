#!/usr/bin/perl

# vim: set ai si sw=2 ts=80:

use XML::XPath;
use DBI;

my $kmlfile = "MillstoneTrails.kml";
my $dbfile = "BarreForestGuide.sqlite";
#my $dbschema = "BarreTrailGuide.schema.sql";

if (@ARGV) { $kmlfile = shift(@ARGV); }
if (@ARGV) { $dbfile = shift(@ARGV); }

unlink($dbfile);
my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile", "", "");

#open(SCHEMA, "<", $dbschema) || die "$!";
my @schema = map($_.=";",split(/;/,join("", <DATA>)));
pop(@schema); # Get rid of the empty statement that the split implicitly creates

$|=1;
printf("Loading schema... ");
$dbh->{AutoCommit} = 0;
while (@schema) { $dbh->do(shift(@schema)) || die $dbh->errstr; }
$dbh->{AutoCommit} = 1;
printf("Done.\n");

printf("Caching uses ID values... ");
my %uses;
my $uses_query = "select id,english_uses from trail_uses;";
foreach my $uses (@{$dbh->selectall_arrayref($uses_query)}) {
  $uses{$uses->[1]} = $uses->[0];
}
printf("Done.\n");

my $ins_uses_sth =
    $dbh->prepare("insert into trail_uses (english_uses) values (?)");
my $ins_map_obj_sth =
    $dbh->prepare("insert into map_object (id,name) values (?,?)");
my $ins_trail_sth =
    $dbh->prepare("insert into trail (id,summer_uses_id,winter_uses_id,meters)".
                    " values (?,?,?,?)");
my $ins_coords_sth =
    $dbh->prepare("insert into coordinate " .
                    "(map_object_id,seq,longitude,lattitude) values (?,?,?,?)");

printf("Parsing trails from XML and inserting into database...\n");
my %fn = ( summer_type => "TRAILTYPES",
           winter_type => "TRAILTYPEW",
           name        => "TRAILNAMES",
           meters      => "METERS",
           id          => "TMPID");
my $k=new XML::XPath(filename=>$kmlfile);
my $inserts = 0;
$dbh->{AutoCommit} = 0;
foreach my $pm ($k->findnodes("/kml/Document/Folder/Placemark")) {
  my $pmd={};
  my $sd=$pm->find("./ExtendedData/SchemaData")->[0];
  foreach my $fn(keys(%fn)) {
    $pmd->{$fn} =
      $sd->find("SimpleData[\@name=\"".$fn{$fn}."\"]")->string_value;
  }
  my $co=$pm->find("./LineString/coordinates")->string_value;
  $co=[map([split(/,/,$_)],split(/\s+/,$co))];
  $pmd->{coords}=$co;
  printf("Inserting trail ID %d\n", $pmd->{id});
  if (!defined($uses{$pmd->{summer_type}})) {
    $ins_uses_sth->execute($pmd->{summer_type});
    $uses{$pmd->{summer_type}} =
      $dbh->last_insert_id(undef, undef, undef, undef);
  }
  if (!defined($uses{$pmd->{winter_type}})) {
    $ins_uses_sth->execute($pmd->{winter_type});
    $uses{$pmd->{winter_type}} =
      $dbh->last_insert_id(undef, undef, undef, undef);
  }
  $ins_map_obj_sth->execute($pmd->{id}, $pmd->{name});
  $ins_trail_sth->execute($pmd->{id}, $uses{$pmd->{summer_type}},
                          $uses{$pmd->{winter_type}}, $pmd->{meters});
  my $seq=1;
  foreach my $waypoint (@$co) {
    $ins_coords_sth->execute($pmd->{id}, $seq++,
                             $waypoint->[0], $waypoint->[1]);
  }
  if (++$inserts%100==0) { $dbh->commit(); }
}
$dbh->commit();
$dbh->{AutoCommit} = 1;
printf("Done.\n");

printf("Caching POI type ID values... ");
my %types;
my $types_query = "select id,english_poi_type from poi_type;";
foreach my $type (@{$dbh->selectall_arrayref($types_query)}) {
  $types{$type->[1]} = $type->[0];
}
printf("Done.\n");

my $ins_poi_type_sth =
    $dbh->prepare("insert into poi_type (english_poi_type) values (?)");
$ins_map_obj_sth =
    $dbh->prepare("insert into map_object (name,url) values (?,?)");
my $ins_poi_sth =
    $dbh->prepare("insert into point_of_interest (id,type_id) values (?,?)");

printf("Inserting POIs into database...\n");
$dbh->{AutoCommit} = 0;
my $url_base="https://raw.githubusercontent.com/BarreForestGuide/trail_images/master/";
foreach my $poi (
  { name=>"MTA Shop",                        type=>"Store",           lat=>44.159882, lon=>-72.470772 }, # No longer include this
  { name=>"Lawson's Store",                  type=>"Store",           lat=>44.159483, lon=>-72.470880 },
  { name=>"South View",                      type=>"Overlook",        lat=>44.136259, lon=>-72.491225 },
  { name=>"Grand Lookout",                   type=>"Overlook",        lat=>44.161278, lon=>-72.476250, url=>"millstone sign grand lookout2.jpg" },
  { name=>"Brook St. Parking Lot",           type=>"Parking Lot",     lat=>44.157065, lon=>-72.469682 },
  { name=>"Little John Parking Lot",         type=>"Parking Lot",     lat=>44.155471, lon=>-72.462611 }, # No longer include this
  { name=>"Barclay Quarry Road Parking Lot", type=>"Parking Lot",     lat=>44.144973, lon=>-72.475652 },
  { name=>"Littlejohn & Milne Quarry",       type=>"Historical Sign", lat=>44.153975, lon=>-72.460692, url=>"millstone -2014- littlejohn & Milne2.jpg" },
  { name=>"The Couture/Wheeler Farm",        type=>"Historical Sign", lat=>44.159102, lon=>-72.467794, url=>"millstone couture wheeler farm 20142.jpg" },
)
{
  printf("Inserting POI \"%s\"\n", $poi->{name});
  if (!defined($types{$poi->{type}})) {
    $ins_poi_type_sth->execute($poi->{type});
    $types{$poi->{type}} = $dbh->last_insert_id(undef, undef, undef, undef);
  }
  $ins_map_obj_sth->execute($poi->{name}, $poi->{url});
  $poi->{id} = $dbh->last_insert_id(undef, undef, undef, undef);
  $ins_poi_sth->execute($poi->{id}, $types{$poi->{type}});
  $ins_coords_sth->execute($poi->{id}, 0, $poi->{lon}, $poi->{lat});
}
$dbh->commit();
$dbh->{AutoCommit} = 1;
printf("Done.\n");

__DATA__

create table map_object (
  id                  integer primary key autoincrement,
  name                varchar,
  description         varchar,
  url                 varchar
);

create table trail_uses (
  id                  integer     primary key autoincrement,
  english_uses        varchar
);

create table trail (
  id                  int,
  summer_uses_id      int,
  winter_uses_id      int,
  meters              double,
  foreign key (id)              references map_object       (id),
  foreign key (summer_uses_id)  references trail_uses       (id),
  foreign key (winter_uses_id)  references trail_uses       (id)
);

create table poi_type (
  id                  integer     primary key autoincrement,
  english_poi_type    varchar
);

create table point_of_interest (
  id                  int,
  type_id             int,
  foreign key (id)              references map_object       (id),
  foreign key (type_id)         references poi_type         (id)
);

create table coordinate (
  map_object_id       int,
  seq                 int,
  lattitude           double,
  longitude           double,
  foreign key (map_object_id)   references map_object       (id)
);
