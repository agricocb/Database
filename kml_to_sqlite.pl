#!/usr/bin/perl

# vim: set ai si sw=2 ts=80:

use XML::XPath;
use DBI;

my $kmlfile = "MillstoneTrails.kml";
my $dbfile = "BarreTrailGuide.sqlite";
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
my $diff_query = "select id,english_difficulty from trail_difficulty;";
my $uses_query = "select id,english_uses from trail_uses;";
foreach my $diff (@{$dbh->selectall_arrayref($diff_query)}) {
  $difficulty{$diff->[1]} = $diff->[0];
}
foreach my $uses (@{$dbh->selectall_arrayref($uses_query)}) {
  $uses{$uses->[1]} = $uses->[0];
}
printf("Done.\n");

my $ins_map_obj_sth =
    $dbh->prepare("insert into map_object (id,name) values (?,?)");
my $ins_trail_sth =
    $dbh->prepare("insert into trail (id,difficulty_id,uses_id,meters) " .
                    "values (?,?,?,?)");
my $ins_coords_sth =
    $dbh->prepare("insert into coordinate (trail_id,seq,lattitude,longitude) " .
                    "values (?,?,?,?)");

printf("Parsing trails from XML and inserting into database...\n");
my %fn = ( difficulty => "TRAILTYPES",
           uses       => "TRAILTYPEW",
           name       => "TRAILNAMES",
           meters     => "METERS",
           id         => "TMPID");
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
  $ins_map_obj_sth->execute($pmd->{id}, $pmd->{name});
  $ins_trail_sth->execute($pmd->{id}, $difficulty{$pmd->{difficulty}},
                          $uses{$pmd->{uses}}, $pmd->{meters});
  my $seq=1;
  foreach my $waypoint (@$co) {
    $ins_coords_sth->execute($pmd->{id}, $seq++, $waypoint->[0], $waypoint->[1]);
  }
  if (++$inserts%100==0) { $dbh->commit(); }
}
$dbh->commit();
printf("Done.\n");
$dbh->{AutoCommit} = 1;

__DATA__

create table trail_difficulty (
  id                  integer     primary key autoincrement,
  english_difficulty  varchar
);

create table trail_uses (
  id                  integer     primary key autoincrement,
  english_uses        varchar
);

create table map_object (
  id                  integer primary key autoincrement,
  name                varchar,
  description         varchar,
  url                 varchar
);

create table trail (
  id                  int,
  difficulty_id       int,
  uses_id             int,
  meters              double,
  foreign key (id)            references map_object       (id),
  foreign key (difficulty_id) references trail_difficulty (id),
  foreign key (uses_id)       references trail_uses       (id)
);

create table coordinate (
  trail_id            int,
  seq                 int,
  lattitude           double,
  longitude           double,
  foreign key (trail_id) references trails(id)
);

insert into trail_difficulty (english_difficulty) values ('BikePath');
insert into trail_difficulty (english_difficulty) values ('Easy');
insert into trail_difficulty (english_difficulty) values ('Extreme');
insert into trail_difficulty (english_difficulty) values ('Hard');
insert into trail_difficulty (english_difficulty) values ('Moderate');
insert into trail_difficulty (english_difficulty) values ('Not');
insert into trail_difficulty (english_difficulty) values ('PvtRd');
insert into trail_difficulty (english_difficulty) values ('Skip');
insert into trail_difficulty (english_difficulty) values ('Walking');

insert into trail_uses (english_uses) values ('Motor');
insert into trail_uses (english_uses) values ('MotorSkiShoe');
insert into trail_uses (english_uses) values ('Not');
insert into trail_uses (english_uses) values ('PvtRd');
insert into trail_uses (english_uses) values ('Shoe');
insert into trail_uses (english_uses) values ('Ski');
insert into trail_uses (english_uses) values ('Skip');
insert into trail_uses (english_uses) values ('SkiShoe');
insert into trail_uses (english_uses) values ('Unmaintained');
