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

printf("Caching difficulty and uses ID values... ");
my %difficulty;
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
    $dbh->prepare("insert into coordinate (trail_id,seq,longitude,lattitude) " .
                    "values (?,?,?,?)");

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
printf("Done.\n");
$dbh->{AutoCommit} = 1;

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

create table coordinate (
  trail_id            int,
  seq                 int,
  lattitude           double,
  longitude           double,
  foreign key (trail_id) references trails(id)
);
