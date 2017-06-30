#!/usr/bin/perl
# Grab results from output files, and present them for plotting

use warnings;
use strict;
use Getopt::Long;
use Mean;

my $barchart;
my $gm;
my $set = 'all';
my $speedup;

GetOptions(
    'barchart' => \$barchart,
    'gmean' => \$gm,
    'set=s' => \$set,
    'speedup' => \$speedup,
    );

my $usage_str = "usage: ./dat.pl [options] file1 [file2 ...]\n" .
    "Options:\n" .
    "  --barchart: output in barchart format, see https://github.com/cota/barchart\n" .
    "  --gmean: include the geometric mean of the results\n" .
    "  --set={all,int,fp}. Default: all\n" .
    "  --speedup: normalize over the results in file1\n";

if (!@ARGV) {
    die $usage_str;
}

my (@files) = @ARGV;
# filenames without extension
my @clean = ();
foreach my $f (@files) {
    my @parts = split('\.', $f);

    if (@parts > 1) {
	pop @parts;
    }
    push @clean, join('.', @parts);
}
my @titles = (@clean);

my @int = qw(400.perlbench 401.bzip2 403.gcc 429.mcf 445.gobmk 456.hmmer
             458.sjeng 462.libquantum 464.h264ref 471.omnetpp 473.astar
             483.xalancbmk);
my @fp = qw(410.bwaves 416.gamess 433.milc 434.zeusmp 435.gromacs 436.cactusADM
            437.leslie3d 444.namd 447.dealII 450.soplex 453.povray 454.calculix
            459.GemsFDTD 465.tonto 470.lbm 481.wrf 482.sphinx3);
my @all = sort (@int, @fp);
my %valid_sets = (
    'int' => \@int,
    'fp' => \@fp,
    'all' => \@all,
    );
die if !$valid_sets{$set};
my @benchmarks = @{ $valid_sets{$set} };

my $res;
foreach my $f (@files) {
    process_file($f);
}
if ($speedup) {
    compute_speedups();
}
if ($gm) {
    compute_gmean($valid_sets{$set});
}
pr();

sub process_file {
    my ($file) = @_;
    open my $in, '<:encoding(UTF-8)', $file or die "Could not open '$file' for reading $!";
    my $grab = 0;
    while (<$in>) {
	chomp;
	if (/^# benchmark\s*/) {
	    $grab = 1;
	    next;
	} elsif (!$grab) {
	    next;
	}
	if (/^EOF/) {
	    $grab = 0;
	    next;
	}
	my ($benchmark, $mean, $stddev) = split("\t");
	$res->{$file}->{$benchmark}->{mean} = $mean;
	$res->{$file}->{$benchmark}->{stddev} = $stddev;
    }
    close $in or die "Could not close '$file': $!";
}

sub pr {
    my @pr_benchmarks = @benchmarks;
    if ($gm) {
	push @pr_benchmarks, 'gmean';
    }
    my @pr_files = @files;
    my @pr_titles = @titles;
    if ($speedup) {
	shift @pr_files;
	shift @pr_titles;
    }
    if ($barchart) {
	pr_barchart(\@pr_benchmarks, \@pr_files, \@pr_titles);
    } else {
	pr_regular(\@pr_benchmarks, \@pr_files, \@pr_titles);
    }
}

sub pr_barchart {
    my ($benchmarks, $files, $titles) = @_;

    print "=cluster;", join(';', @$titles), "\n";
    pr_table($benchmarks, $files, 'mean', '=table');
    pr_table($benchmarks, $files, 'stddev', '=yerrorbars');
}

sub pr_table {
    my ($benchmarks, $files, $field, $pr) = @_;

    print "$pr\n";
    foreach my $b (@$benchmarks) {
	my @arr = ();
	for my $f (@$files) {
	    my $r = $res->{$f}->{$b};

	    push @arr, $r->{$field};
	}
	print join("\t", "\"$b\"", @arr), "\n";
    }
}

sub pr_regular {
    my ($benchmarks, $files, $titles) = @_;

    print join("\t", '# Benchmark', map { $_, 'err' } @$titles), "\n";
    foreach my $b (@$benchmarks) {
	my @a = ($b);
	foreach my $f (@$files) {
	    my $r = $res->{$f}->{$b} ||
		die "fatal: no results for benchmark '$b' in file '$f'. " .
		"You might want to try specifying a different --set.\n";

	    push @a, $r->{mean}, $r->{stddev};
	}
	print join("\t", @a), "\n";
    }
}

sub compute_speedups {
    if (@files == 1) {
	die "fatal: computing --speedup with only one input file makes no sense\n";
    }
    for (my $i = 1; $i < @files; $i++) {
	for my $bench (@benchmarks) {
	    my $a = $res->{$files[0]}->{$bench};
	    my $b = $res->{$files[$i]}->{$bench};

	    my $val = $a->{mean} / $b->{mean};

	    my $a_rel = $a->{stddev} / $a->{mean};
	    my $b_rel = $b->{stddev} / $b->{mean};
	    my $rel = Mean::sqrt_sum([ $a_rel, $b_rel ]);
	    my $err = $rel * $val;
	    $res->{$files[$i]}->{$bench}->{mean} = $val;
	    $res->{$files[$i]}->{$bench}->{stddev} = $err;
	}
    }
    for my $bench (@benchmarks) {
	my $r = $res->{$files[0]}->{$bench};
	my $div_by = $r->{mean};

	$res->{$files[0]}->{$bench}->{mean} /= $div_by;
	$res->{$files[0]}->{$bench}->{stddev} /= $div_by;
    }
}

sub compute_gmean {
    foreach my $f (@files) {
	my @vals;
	my @errors;
	foreach my $b (@benchmarks) {
	    my $r = $res->{$f}->{$b} || die; # should have been caught earlier

	    push @vals, $r->{mean};
	    push @errors, $r->{stddev};
	}
	my ($gmean, $err) = Mean::geometric_err(\@vals, \@errors);
	$res->{$f}->{gmean}->{mean} = $gmean;
	$res->{$f}->{gmean}->{stddev} = $err;
    }
}
