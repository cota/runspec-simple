#!/usr/bin/perl
# Grab results from output files, and present them for plotting

use warnings;
use strict;
use Getopt::Long;
use File::Basename;
use lib dirname (__FILE__);
use Stats;

my $barchart;
my $gm;
my $set = 'all';
my $speedup;
my $slowdown;
my $confidence = 0.95;
my $cumulative;
my $titles;
my $force_n_samples;
my $int_geomean_name = 'geomean';
my $fp_geomean_name = 'geomean';
my @extra_barchart_args;
my @extra_gnuplot_args;
my $cherry_pick;

GetOptions(
    'barchart' => \$barchart, # ignored; left here for backwards compatibility
    'cherry-pick=s' => \$cherry_pick,
    'confidence=f' => \$confidence,
    'cumulative' => \$cumulative,
    'force_n_samples=i' => \$force_n_samples,
    'fp-gmean-name=s' => \$fp_geomean_name,
    'extra=s' => \@extra_barchart_args,
    'extra-gnuplot=s' => \@extra_gnuplot_args,
    'int-gmean-name=s' => \$int_geomean_name,
    'gmean' => \$gm,
    'set=s' => \$set,
    'speedup' => \$speedup,
    'slowdown' => \$slowdown,
    'titles=s' => \$titles,
    );

my $usage_str = "usage: ./dat.pl [options] file1 [file2 ...]\n" .
    "Options:\n" .
    "  --cherry-pick: pick benchmarks separately, instead of passing them via --set\n" .
    "  --confidence: confidence interval (default: 0.95)\n" .
    "  --cumulative: interpret data as a stacked chart\n" .
    "  --force_n_samples: force a number of samples per benchmark (useful when the
           input data was not generated with --show-raw)\n" .
    "  --fp-gmean-name: name (label) of the floating point (FP) geometric mean\n" .
    "  --extra: add extra commands to barchart\n" .
    "  --extra-gnuplot: add extra commands to gnuplot\n" .
    "  --int-gmean-name: name (label) of the integer (INT) geometric mean\n" .
    "  --gmean: include the geometric mean of the results\n" .
    "  --set={all,int,fp}. Default: all\n" .
    "  --speedup: normalize over the results in file1\n" .
    "  --slowdown: 1/speedup\n" .
    "  --titles: comma-separated titles of the input files\n";

if (!@ARGV) {
    die $usage_str;
}

my (@files) = @ARGV;
my @titles;
if (defined($titles)) {
    @titles = split(',', $titles);
}
if (scalar(@titles) == 0) {
    # filenames without extension
    my @clean = ();
    foreach my $f (@files) {
	my @parts = split('\.', $f);

	if (@parts > 1) {
	    pop @parts;
	}
	push @clean, join('.', @parts);
    }
    @titles = (@clean);
}

my @int = qw(400.perlbench 401.bzip2 403.gcc 429.mcf 445.gobmk 456.hmmer
             458.sjeng 462.libquantum 464.h264ref 471.omnetpp 473.astar
             483.xalancbmk);
my @fp = qw(410.bwaves 416.gamess 433.milc 434.zeusmp 435.gromacs 436.cactusADM
            437.leslie3d 444.namd 447.dealII 450.soplex 453.povray 454.calculix
            459.GemsFDTD 465.tonto 470.lbm 481.wrf 482.sphinx3);
my @all = ();

if (defined($cherry_pick)) {
    @all = split(',', $cherry_pick);
} else {
    @all = sort (@int, @fp);
}
my %valid_sets = (
    'int' => \@int,
    'fp' => \@fp,
    'all' => \@all,
    );
die if !$valid_sets{$set};
my @benchmarks;
if (defined($cherry_pick)) {
    @benchmarks = @all;
} else {
    @benchmarks = @{ $valid_sets{$set} };
}
die if ($speedup and $slowdown);

my $res;
foreach my $f (@files) {
    process_file($f);
}
compute_means();
if ($speedup or $slowdown) {
    compute_speedups();
}
if ($gm) {
    if (defined($cherry_pick)) {
	compute_gmean(\@benchmarks, 'geomean');
    } else {
	if ($set eq 'all' or $set eq 'int') {
	    compute_gmean($valid_sets{'int'}, $int_geomean_name);
	}
	if ($set eq 'all' or $set eq 'fp') {
	    compute_gmean($valid_sets{'fp'}, $fp_geomean_name);
	}
    }
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
	my ($benchmark, $mean, $stddev, $raw) = split("\t");
	if (defined($raw)) {
	    my $r = $res->{$file}{$benchmark}{raw} //= [];
	    push @{ $r }, split(',', $raw);
	} else {
	    die if !defined($force_n_samples);
	    my $r = $res->{$file}{$benchmark} //= {};
	    die if defined($r->{mean});
	    @$r{qw/mean stddev/} = ($mean, $stddev);
	}
    }
    close $in or die "Could not close '$file': $!";
}

sub compute_means {
    foreach my $file (keys %{ $res }) {
	foreach my $bench (keys %{ $res->{$file} }) {
	    my $r = $res->{$file}{$bench};

	    if (defined($r->{raw})) {
		my $mean = Stats::arithmetic($r->{raw});
		my $stdv = Stats::stdev($r->{raw});
		my $n = scalar(@{ $r->{raw} });
		my ($lo, $hi) = Stats::conf_interval($n, $mean, $stdv, $confidence);
		@$r{qw/mean stddev dev lo hi/} = ($mean, $stdv, $hi - $mean, $lo, $hi);
	    } else {
		die if !defined($force_n_samples);
		my $mean = $r->{mean};
		my $stddev = $r->{stddev};
		my ($lo, $hi) = Stats::conf_interval($force_n_samples, $mean, $stddev, $confidence);
		@$r{qw/dev lo hi/} = ($hi - $r->{mean}, $lo, $hi);
	    }
	}
    }
}

sub pr {
    my @pr_benchmarks;

    if ($set eq 'all' or $set eq 'int') {
	if (defined($cherry_pick)) {
	    push @pr_benchmarks, @all;
	} else {
	    push @pr_benchmarks, @int;
	}
	if ($gm) {
	    push @pr_benchmarks, $int_geomean_name;
	}
    }
    if (!defined($cherry_pick) and ($set eq 'all' or $set eq 'fp')) {
	push @pr_benchmarks, @fp;
	if ($gm) {
	    push @pr_benchmarks, $fp_geomean_name;
	}
    }

    my @pr_files = @files;
    my @pr_titles = @titles;
    if ($speedup or $slowdown) {
	shift @pr_files;
	shift @pr_titles;
    }
    pr_barchart(\@pr_benchmarks, \@pr_files, \@pr_titles);
}

sub pr_barchart {
    my ($benchmarks, $files, $titles) = @_;

    my $keyword = 'cluster';
    if ($cumulative) {
	$keyword = 'stacked';
    }
    if (@extra_barchart_args) {
	print join("\n", map { "$_" } @extra_barchart_args), "\n";
    }
    if (@extra_gnuplot_args) {
	print join("\n", map { "extraops=$_" } @extra_gnuplot_args), "\n";
    }
    print "=$keyword;", join(';', @$titles), "\n";
    if (!$cumulative) {
	pr_table($benchmarks, $files, 'mean', '=table');
	pr_table($benchmarks, $files, 'dev', '=yerrorbars');
    } else {
	pr_cumul($benchmarks, $files, 'mean', '=multi');
    }
}

sub pr_cumul {
    my ($benchmarks, $files, $field, $pr) = @_;

    my %prev;
    foreach my $file (@$files) {
	foreach my $bench (@$benchmarks) {
	    my @pr = ($bench);
	    my $p = $prev{$bench} //= 0;
	    my $val = $res->{$file}{$bench}{$field};
	    push @pr, $val - $p > 0 ? $val - $p : 0;
	    print join("\t", @pr), "\n";
	    $prev{$bench} = $val;
	}
	print "$pr\n";
    }
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
	die "fatal: computing --speedup/slowdown with only one input file makes no sense\n";
    }
    for (my $i = 1; $i < @files; $i++) {
	for my $bench (@benchmarks) {
	    my $a = $res->{$files[0]}->{$bench};
	    my $b = $res->{$files[$i]}->{$bench};

	    my $val = $a->{mean} / $b->{mean};
	    if ($slowdown) {
		$val = 1 / $val;
	    }

	    my $a_rel = $a->{dev} / $a->{mean};
	    my $b_rel = $b->{dev} / $b->{mean};
	    my $rel = Stats::sqrt_sum([ $a_rel, $b_rel ]);
	    my $err = $rel * $val;
	    $res->{$files[$i]}->{$bench}->{mean} = $val;
	    $res->{$files[$i]}->{$bench}->{dev} = $err;
	}
    }
    for my $bench (@benchmarks) {
	my $r = $res->{$files[0]}->{$bench};
	my $div_by = $r->{mean};

	$res->{$files[0]}->{$bench}->{mean} /= $div_by;
	$res->{$files[0]}->{$bench}->{dev} /= $div_by;
    }
}

sub compute_gmean {
    my ($benchmarks, $geoname) = @_;

    foreach my $f (@files) {
	my @vals;
	my @errors;
	foreach my $b (@{ $benchmarks }) {
	    my $r = $res->{$f}->{$b} || die; # should have been caught earlier

	    push @vals, $r->{mean};
	    push @errors, $r->{dev};
	}
	my ($gmean, $err) = Stats::geometric_err(\@vals, \@errors);
	$res->{$f}->{$geoname}->{mean} = $gmean;
	$res->{$f}->{$geoname}->{dev} = $err;
    }
}
