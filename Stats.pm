# Stats.pm
# roll our own basic stats to avoid CPAN dependencies
package Stats;

use warnings;
use strict;
use Exporter qw(import);
use Carp;

our @EXPORT_OK = qw(arithmetic conf_interval geometric geometric_err harmonic stdev);

sub arithmetic {
    my ($data) = @_;

    if (not @$data) {
	croak "Empty array";
    }
    my $total = 0;
    foreach (@$data) {
	$total += $_;
    }
    my $mean = $total / @$data;
    return $mean;
}

# corrected sample standard deviation
# http://en.wikipedia.org/wiki/Standard_deviation
sub stdev {
    my ($data) = @_;

    if (@$data == 1) {
	return 0;
    }
    my $mean = &arithmetic($data);
    my $sqtotal = 0;
    foreach (@$data) {
	$sqtotal += ($mean-$_) ** 2;
    }
    my $std = ($sqtotal / (@$data-1)) ** 0.5;
    return $std;
}

sub geometric {
    my ($data) = @_;

    if (not @$data) {
	croak "Empty array";
    }
    my $total = 1;
    foreach (@$data) {
	if ($_ < 0) {
	    croak "Cannot use geometric mean on negative values (val: $_)";
	}
	$total *= $_;
    }
    my $mean = $total ** (1 / scalar(@$data));
    return $mean;
}

sub geometric_err {
    my ($data, $errs) = @_;

    if (not @$data or not @$errs) {
	croak "Empty array";
    }
    if (scalar(@$data) != scalar(@$errs)) {
	croak "data != errs";
    }
    my $total = 1;

    for (my $i = 0; $i < @$data; $i++) {
	my $v = $data->[$i];
	if ($v < 0) {
	    croak "Cannot use geometric mean on negative values (val: $v)";
	}
	$total *= $v;
    }
    my @rels = ();
    for (my $i = 0; $i < @$errs; $i++) {
	my $v = $data->[$i];
	my $e = $errs->[$i];
	my $rel = $e / $v;
	push @rels, $rel;
    }
    my $rel = sqrt_sum(\@rels);

    my $mean = $total ** (1.0 / scalar(@$data));
    $rel *= 1.0 / scalar(@$data);
    my $err = $rel * $mean;
    return ($mean, $err);
}

sub inv_err {
    my ($v, $err) = @_;

    my $rel = $err / $v;
    my $r = 1.0 / $v;
    return ($r, $rel * $r);
}

sub sqrt_sum {
    my ($data) = @_;

    my $v = 0;
    foreach (@$data) {
	$v += $_ * $_;
    }
    return sqrt($v);
}

sub sum_err {
    my ($data, $err) = @_;

    my $r = 0;
    foreach (@$data) {
	$r += $_;
    }
    return ($r, sqrt_sum($err));
}

sub harmonic {
    my ($data, $err) = @_;

    if (not @$data) {
	croak "Empty array";
    }

    if ($err) {
	my @values = ();
	my @errors = ();
	for (my $i = 0; $i < scalar(@$data); $i++) {
	    my ($v, $e) = inv_err($data->[$i], $err->[$i]);
	    push @values, $v;
	    push @errors, $e;
	}
	my ($v, $e) = sum_err(\@values, \@errors);
	($v, $e) = inv_err($v, $e);
	my $rel = $e / $v;
	$v *= scalar(@$data);
	return ($v, $rel * $v);
    } else {
	my $v = 0;
	foreach (@$data) {
	    $v += 1.0 / $_;
	}
	return scalar(@$data) / $v;
    }
}

sub conf_interval {
    my ($n, $mean, $stddev, $conf) = @_;
    # Source: http://www.sjsu.edu/faculty/gerstman/StatPrimer/t-table.pdf
    my $t_dist = {
	.25 => {
	    1 => 1.000,
	    2 => 0.816,
	    3 => 0.765,
	    4 => 0.741,
	    5 => 0.727,
	    6 => 0.718,
	    7 => 0.711,
	    8 => 0.706,
	    9 => 0.703,
	    10 => 0.700,
	    11 => 0.697,
	    12 => 0.695,
	    13 => 0.694,
	    14 => 0.692,
	    15 => 0.691,
	    16 => 0.690,
	    17 => 0.689,
	    18 => 0.688,
	    19 => 0.688,
	    20 => 0.687,
	    21 => 0.686,
	    22 => 0.686,
	    23 => 0.685,
	    24 => 0.685,
	    25 => 0.684,
	    26 => 0.684,
	    27 => 0.684,
	    28 => 0.683,
	    29 => 0.683,
	    30 => 0.683,
	    40 => 0.681,
	    50 => 0.679,
	    60 => 0.679,
	    80 => 0.678,
	    100 => 0.677,
	    1000 => 0.675,
	    1001 => 0.674,
	},
	.20 => {
	    1 => 1.376,
	    2 => 1.061,
	    3 => 0.978,
	    4 => 0.941,
	    5 => 0.920,
	    6 => 0.906,
	    7 => 0.896,
	    8 => 0.889,
	    9 => 0.883,
	    10 => 0.879,
	    11 => 0.876,
	    12 => 0.873,
	    13 => 0.870,
	    14 => 0.868,
	    15 => 0.866,
	    16 => 0.865,
	    17 => 0.863,
	    18 => 0.862,
	    19 => 0.861,
	    20 => 0.860,
	    21 => 0.859,
	    22 => 0.858,
	    23 => 0.858,
	    24 => 0.857,
	    25 => 0.856,
	    26 => 0.856,
	    27 => 0.855,
	    28 => 0.855,
	    29 => 0.854,
	    30 => 0.854,
	    40 => 0.851,
	    50 => 0.849,
	    60 => 0.848,
	    80 => 0.846,
	    100 => 0.845,
	    1000 => 0.842,
	    1001 => 0.841,
	},
	.15 => {
	    1 => 1.963,
	    2 => 1.386,
	    3 => 1.250,
	    4 => 1.190,
	    5 => 1.156,
	    6 => 1.134,
	    7 => 1.119,
	    8 => 1.108,
	    9 => 1.100,
	    10 => 1.093,
	    11 => 1.088,
	    12 => 1.083,
	    13 => 1.079,
	    14 => 1.076,
	    15 => 1.074,
	    16 => 1.071,
	    17 => 1.069,
	    18 => 1.067,
	    19 => 1.066,
	    20 => 1.064,
	    21 => 1.063,
	    22 => 1.061,
	    23 => 1.060,
	    24 => 1.059,
	    25 => 1.058,
	    26 => 1.058,
	    27 => 1.057,
	    28 => 1.056,
	    29 => 1.055,
	    30 => 1.055,
	    40 => 1.050,
	    50 => 1.047,
	    60 => 1.045,
	    80 => 1.043,
	    100 => 1.042,
	    1000 => 1.037,
	    1001 => 1.036,
	},
	.10 => {
	    1 => 3.078,
	    2 => 1.886,
	    3 => 1.638,
	    4 => 1.533,
	    5 => 1.476,
	    6 => 1.440,
	    7 => 1.415,
	    8 => 1.397,
	    9 => 1.383,
	    10 => 1.372,
	    11 => 1.363,
	    12 => 1.356,
	    13 => 1.350,
	    14 => 1.345,
	    15 => 1.341,
	    16 => 1.337,
	    17 => 1.333,
	    18 => 1.330,
	    19 => 1.328,
	    20 => 1.325,
	    21 => 1.323,
	    22 => 1.321,
	    23 => 1.319,
	    24 => 1.318,
	    25 => 1.316,
	    26 => 1.315,
	    27 => 1.314,
	    28 => 1.313,
	    29 => 1.311,
	    30 => 1.310,
	    40 => 1.303,
	    50 => 1.299,
	    60 => 1.296,
	    80 => 1.292,
	    100 => 1.290,
	    1000 => 1.282,
	    1001 => 1.282,
	},
	.05 => {
	    1 => 6.314,
	    2 => 2.920,
	    3 => 2.353,
	    4 => 2.132,
	    5 => 2.015,
	    6 => 1.943,
	    7 => 1.895,
	    8 => 1.860,
	    9 => 1.833,
	    10 => 1.812,
	    11 => 1.796,
	    12 => 1.782,
	    13 => 1.771,
	    14 => 1.761,
	    15 => 1.753,
	    16 => 1.746,
	    17 => 1.740,
	    18 => 1.734,
	    19 => 1.729,
	    20 => 1.725,
	    21 => 1.721,
	    22 => 1.717,
	    23 => 1.714,
	    24 => 1.711,
	    25 => 1.708,
	    26 => 1.706,
	    27 => 1.703,
	    28 => 1.701,
	    29 => 1.699,
	    30 => 1.697,
	    40 => 1.684,
	    50 => 1.676,
	    60 => 1.671,
	    80 => 1.664,
	    100 => 1.660,
	    1000 => 1.646,
	    1001 => 1.645,
	},
	.025 => {
	    1 => 12.71,
	    2 => 4.303,
	    3 => 3.182,
	    4 => 2.776,
	    5 => 2.571,
	    6 => 2.447,
	    7 => 2.365,
	    8 => 2.306,
	    9 => 2.262,
	    10 => 2.228,
	    11 => 2.201,
	    12 => 2.179,
	    13 => 2.160,
	    14 => 2.145,
	    15 => 2.131,
	    16 => 2.120,
	    17 => 2.110,
	    18 => 2.101,
	    19 => 2.093,
	    20 => 2.086,
	    21 => 2.080,
	    22 => 2.074,
	    23 => 2.069,
	    24 => 2.064,
	    25 => 2.060,
	    26 => 2.056,
	    27 => 2.052,
	    28 => 2.048,
	    29 => 2.045,
	    30 => 2.042,
	    40 => 2.021,
	    50 => 2.009,
	    60 => 2.000,
	    80 => 1.990,
	    100 => 1.984,
	    1000 => 1.962,
	    1001 => 1.960,
	},
	.02 => {
	    1 => 15.89,
	    2 => 4.849,
	    3 => 3.482,
	    4 => 2.999,
	    5 => 2.757,
	    6 => 2.612,
	    7 => 2.517,
	    8 => 2.449,
	    9 => 2.398,
	    10 => 2.359,
	    11 => 2.328,
	    12 => 2.303,
	    13 => 2.282,
	    14 => 2.264,
	    15 => 2.249,
	    16 => 2.235,
	    17 => 2.224,
	    18 => 2.214,
	    19 => 2.205,
	    20 => 2.197,
	    21 => 2.189,
	    22 => 2.183,
	    23 => 2.177,
	    24 => 2.172,
	    25 => 2.167,
	    26 => 2.162,
	    27 => 2.158,
	    28 => 2.154,
	    29 => 2.150,
	    30 => 2.147,
	    40 => 2.123,
	    50 => 2.109,
	    60 => 2.099,
	    80 => 2.088,
	    100 => 2.081,
	    1000 => 2.056,
	    1001 => 2.054,
	},
	.01 => {
	    1 => 31.82,
	    2 => 6.965,
	    3 => 4.541,
	    4 => 3.747,
	    5 => 3.365,
	    6 => 3.143,
	    7 => 2.998,
	    8 => 2.896,
	    9 => 2.821,
	    10 => 2.764,
	    11 => 2.718,
	    12 => 2.681,
	    13 => 2.650,
	    14 => 2.624,
	    15 => 2.602,
	    16 => 2.583,
	    17 => 2.567,
	    18 => 2.552,
	    19 => 2.539,
	    20 => 2.528,
	    21 => 2.518,
	    22 => 2.508,
	    23 => 2.500,
	    24 => 2.492,
	    25 => 2.485,
	    26 => 2.479,
	    27 => 2.473,
	    28 => 2.467,
	    29 => 2.462,
	    30 => 2.457,
	    40 => 2.423,
	    50 => 2.403,
	    60 => 2.390,
	    80 => 2.374,
	    100 => 2.364,
	    1000 => 2.330,
	    1001 => 2.326,
	},
	.005 => {
	    1 => 63.66,
	    2 => 9.925,
	    3 => 5.841,
	    4 => 4.604,
	    5 => 4.032,
	    6 => 3.707,
	    7 => 3.499,
	    8 => 3.355,
	    9 => 3.250,
	    10 => 3.169,
	    11 => 3.106,
	    12 => 3.055,
	    13 => 3.012,
	    14 => 2.977,
	    15 => 2.947,
	    16 => 2.921,
	    17 => 2.898,
	    18 => 2.878,
	    19 => 2.861,
	    20 => 2.845,
	    21 => 2.831,
	    22 => 2.819,
	    23 => 2.807,
	    24 => 2.797,
	    25 => 2.787,
	    26 => 2.779,
	    27 => 2.771,
	    28 => 2.763,
	    29 => 2.756,
	    30 => 2.750,
	    40 => 2.704,
	    50 => 2.678,
	    60 => 2.660,
	    80 => 2.639,
	    100 => 2.626,
	    1000 => 2.581,
	    1001 => 2.576,
	},
	.0025 => {
	    1 => 127.3,
	    2 => 14.09,
	    3 => 7.453,
	    4 => 5.598,
	    5 => 4.773,
	    6 => 4.317,
	    7 => 4.029,
	    8 => 3.833,
	    9 => 3.690,
	    10 => 3.581,
	    11 => 3.497,
	    12 => 3.428,
	    13 => 3.372,
	    14 => 3.326,
	    15 => 3.286,
	    16 => 3.252,
	    17 => 3.222,
	    18 => 3.197,
	    19 => 3.174,
	    20 => 3.153,
	    21 => 3.135,
	    22 => 3.119,
	    23 => 3.104,
	    24 => 3.091,
	    25 => 3.078,
	    26 => 3.067,
	    27 => 3.057,
	    28 => 3.047,
	    29 => 3.038,
	    30 => 3.030,
	    40 => 2.971,
	    50 => 2.937,
	    60 => 2.915,
	    80 => 2.887,
	    100 => 2.871,
	    1000 => 2.813,
	    1001 => 2.807,
	},
	.001 => {
	    1 => 318.3,
	    2 => 22.33,
	    3 => 10.21,
	    4 => 7.173,
	    5 => 5.893,
	    6 => 5.208,
	    7 => 4.785,
	    8 => 4.501,
	    9 => 4.297,
	    10 => 4.144,
	    11 => 4.025,
	    12 => 3.930,
	    13 => 3.852,
	    14 => 3.787,
	    15 => 3.733,
	    16 => 3.686,
	    17 => 3.646,
	    18 => 3.611,
	    19 => 3.579,
	    20 => 3.552,
	    21 => 3.527,
	    22 => 3.505,
	    23 => 3.485,
	    24 => 3.467,
	    25 => 3.450,
	    26 => 3.435,
	    27 => 3.421,
	    28 => 3.408,
	    29 => 3.396,
	    30 => 3.385,
	    40 => 3.307,
	    50 => 3.261,
	    60 => 3.232,
	    80 => 3.195,
	    100 => 3.174,
	    1000 => 3.098,
	    1001 => 3.091,
	},
	.0005 => {
	    1 => 636.6,
	    2 => 31.60,
	    3 => 12.92,
	    4 => 8.610,
	    5 => 6.869,
	    6 => 5.959,
	    7 => 5.408,
	    8 => 5.041,
	    9 => 4.781,
	    10 => 4.587,
	    11 => 4.437,
	    12 => 4.318,
	    13 => 4.221,
	    14 => 4.140,
	    15 => 4.073,
	    16 => 4.015,
	    17 => 3.965,
	    18 => 3.922,
	    19 => 3.883,
	    20 => 3.850,
	    21 => 3.819,
	    22 => 3.792,
	    23 => 3.768,
	    24 => 3.745,
	    25 => 3.725,
	    26 => 3.707,
	    27 => 3.690,
	    28 => 3.674,
	    29 => 3.659,
	    30 => 3.646,
	    40 => 3.551,
	    50 => 3.496,
	    60 => 3.460,
	    80 => 3.416,
	    100 => 3.390,
	    1000 => 3.300,
	    1001 => 3.291,
	},
    };

    die if $n == 0;
    if ($n == 1) {
	return ($mean, $mean);
    }
    my $cum_prob = 1 - $conf;
    if (!defined($t_dist->{$cum_prob})) {
	die "cannot find a t-dist table for $conf confidence";
    }
    my $t = $t_dist->{$cum_prob}->{$n - 1};
    if (!defined($t)) {
	die "t-dist interpolation not implemented";
    }

    my $dev = $t * $stddev / sqrt($n);
    return ($mean - $dev, $mean + $dev);
}

1;
