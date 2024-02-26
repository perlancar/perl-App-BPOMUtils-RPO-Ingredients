package App::BPOMUtils::RPO::Ingredients;

use 5.010001;
use locale;
use strict;
use warnings;
use Log::ger;

use Exporter 'import';
use POSIX 'setlocale', 'LC_ALL';

# AUTHORITY
# DATE
# DIST
# VERSION

our @EXPORT_OK = qw(
                       bpom_rpo_ingredients_group_for_label
               );

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
};

$SPEC{bpom_rpo_ingredients_group_for_label} = {
    v => 1.1,
    summary => 'Group ingredients suitable for food label',
    description => <<'_',

This utility accepts a CSV data from stdin. The CSV must be formatted like this:

    Ingredient,%weight,"Ingredient name for label (Indonesian)","Ingredient name for label (English)","QUID?","Note (Indonesian)","Note (English)","Ingredient group for label (Indonesian)","Ingredient group for label (English)"
    Air,78.48,Air,Water,,
    Gula,16.00,Gula,Sugar,,"mengandung pengawet sulfit","contains sulfite preservative",
    "Nata de coco",5.00,"Nata de coco","Nata de coco",1,"mengandung pengawet sulfit","contains sulfit preservative",
    "Asam sitrat",0.25,"Asam sitrat","Citric acid",,,,"Pengatur keasaman","Acidity regulator"
    "Asam malat",0.10,"Asam malat","Malic acid",,,,"Pengatur keasaman","Acidity regulator"
    "Grape flavor",0.10,Anggur,Grape,,,,"Perisa sintetik","Synthetic flavoring"
    "Tea flavor",0.05,Teh,Tea,,,,"Perisa sintetik","Synthetic flavoring"
    "Natrium benzoat",0.02,"Natrium benzoat","Sodium benzoate",,,,Pengawet,Preservative

It can then group the ingredients based on the ingredient group and generate
this (for Indonesian, `--lang ind`):

    Ingredient,%weight
    Air,78.48
    Gula (mengandung pengawet sulfit),16.00
    "Nata de coco 5% (mengandung pengawet sulfit)",5.00
    "Pengatur keasaman (Asam sitrat, Asam malat)",0.35
    "Perisa sintetik (Anggur, Teh)",0.15
    "Pengawet Natrium benzoat",0.02

And for English, `--lang eng`:

    Ingredient,%weight
    Water,78.48
    Sugar (contains sulfite preservative),16.00
    "Nata de coco 5% (contains sulfite preservative)",5.00
    "Acidity regulator (Citric acid, Malic acid)",0.35
    "Synthetic flavoring (Grape, Tea)",0.15
    "Preservative Sodium benzoate",0.02

_
    args => {
        lang => {
            schema => ['str*', in=>['eng','ind']],
            default => 'ind',
        },
        precision => {
            schema => ['uint*'], # TODO: support -1 precision (e.g. 11% -> 10%)
            default => 4,
        },
    },
};
sub bpom_rpo_ingredients_group_for_label {
    require Text::CSV;

    my %args = @_;

    my $csv = Text::CSV->new({binary=>1, auto_diag=>1});
    my @rows;
    while (my $row = $csv->getline(\*STDIN)) { push @rows, $row }

    if ($args{lang} eq 'ind') {
        POSIX::setlocale(LC_ALL, "id_ID.UTF-8") or die "Can't set locale to id_ID.UTF-8";
    } else {
    }

    my %weights; # key = ingredient name, value = weight
    my %ingredients; # key = name, value = { weight=>, items=> }
    for my $n (1 .. $#rows) {
        my $row = $rows[$n];
        my ($ingredient0, $weight, $ind_ingredient, $eng_ingredient, $quid, $ind_note, $eng_note, $ind_group, $eng_group) = @$row;
        my ($label_ingredient0, $note, $group) = $args{lang} eq 'eng' ? ($eng_ingredient, $eng_note, $eng_group) : ($ind_ingredient, $ind_note, $ind_group);

        my $label_ingredient = join(
            " ",
            $label_ingredient0,
            ($quid ? (sprintf "%".(defined $args{precision} ? ".$args{precision}" : '')."g%%", $weight) : ()),
            ($note ? ("($note)") : ()),
        );

        my $has_group;
        if ($group) { $has_group++ } else { $group = $label_ingredient }
        $weights{$ingredient0} = $weight;
        $ingredients{ $group } //= {has_group=>$has_group, ingredient0 => $ingredient0};
        $ingredients{ $group }{weight} //= 0;
        $ingredients{ $group }{items} //= [];
        $ingredients{ $group }{items0} //= [];
        $ingredients{$group}{weight} += $weight;
        push @{ $ingredients{$group}{items} }, $label_ingredient;
        push @{ $ingredients{$group}{items0} }, $ingredient0;
    }

    @rows = ();
    my $i = 0;
    for my $group (sort { ($ingredients{$b}{weight} <=> $ingredients{$a}{weight}) || ($a cmp $b) } keys %ingredients) {
        $i++;
        my $ingredient = $group;
        if ($ingredients{$group}{has_group}) {
            $ingredient .= " ";
            if (@{ $ingredients{$group}{items} } > 1) {
                my @items = map { $ingredients{$group}{items}[$_] }
                    sort { $weights{ $ingredients{$group}{items0}[$b] } <=> $weights{ $ingredients{$group}{items0}[$b] } } 0 .. $#{ $ingredients{$group}{items} };
                $ingredient .= "(" . join(", ", @items) . ")";
            } else {
                $ingredient .= $ingredients{$group}{items}[0];
            }
        }
        push @rows, [$ingredient, $ingredients{$group}{weight}];
    }

    [200, "OK", \@rows, {'table.fields'=>['Ingredient', '%weight']}];
}

1;
#ABSTRACT:

=head1 SYNOPSIS


=head1 DESCRIPTION

This distribution includes CLI utilities related to helping with Processed Food
Registration (RPO - Registrasi Pangan Olahan), particularly with regards to
ingredients.

# INSERT_EXECS_LIST


=head1 SEE ALSO

L<https://registrasipangan.pom.go.id>

=cut
