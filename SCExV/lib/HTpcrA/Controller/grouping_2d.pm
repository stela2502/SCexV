package HTpcrA::Controller::grouping_2d;
use Moose;
use namespace::autoclean;

with 'HTpcrA::EnableFiles';

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

HTpcrA::Controller::grouping_2d - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index : Path : Form {
	my ( $self, $c, $geneA, $geneB ) = @_;
	my $path = $self->check($c);
	
	my $hash = $self->config_file( $c, 'grouping2D.txt' );
	$c->stash->{'script'} = $self->Javascript($c);
	$self->{'form_array'} = [];
	opendir( DIR, $path . "preprocess/" );

#Carp::confess ( join(", ",(map {$_ =~ s/.array.png//; $_; } grep /.array.png/ , readdir(DIR) ) ) ."\n");
	my @genes = sort map { $_ =~ s/.png//; $_; } grep /.png/, readdir(DIR);
	closedir(DIR);
	my $type = 'hidden';

	#	my $type = 'text';
	push(
		@{ $self->{'form_array'} },
		{
			'comment'  => 'x axis gene',
			'name'     => 'gx',
			'options'  => \@genes,
			'required' => 1,
			'value'    => $geneA,
		}
	);
	push(
		@{ $self->{'form_array'} },
		{
			'comment'  => 'y axis gene',
			'name'     => 'gy',
			'options'  => \@genes,
			'required' => 1,
			'value'    => $geneB,
		}
	);
	push(
		@{ $self->{'form_array'} },
		{
			'comment'  => 'x1',
			'name'     => 'x1',
			'type'     => $type,
			'required' => 0,
		}
	);
	push(
		@{ $self->{'form_array'} },
		{
			'comment'  => 'x2',
			'name'     => 'x2',
			'type'     => $type,
			'required' => 0,
		}
	);
	push(
		@{ $self->{'form_array'} },
		{
			'comment'  => 'y1',
			'name'     => 'y1',
			'type'     => $type,
			'required' => 0,
		}
	);
	push(
		@{ $self->{'form_array'} },
		{
			'comment'  => 'y2',
			'name'     => 'y2',
			'type'     => $type,
			'required' => 0,
		}
	);

	$c->form->submit(
		[ 'Submit', 'Clear all groups', 'Analyze using this grouping' ] );
	foreach ( @{ $self->{'form_array'} } ) {
		$c->form->field( %{$_} );
	}
	my $gg = $c->model('GeneGroups');

	my $data = $gg->read_data( $c->session_path() . 'merged_data_Table.xls',
		my $use_data_table_obj = 1 );
	if ( $c->form->submitted && $c->form->validate ) {
		my $dataset = $self->__process_returned_form($c);
		$dataset->{'gg'} = $c->model('GeneGroups');
		unless (
			join( ' ', $geneA,           $geneB ) eq
			join( " ", $dataset->{'gx'}, $dataset->{'gy'} ) )
		{
			## I need to kill x and y informations as they are not based on this gene set!
			$c->res->redirect(
				$c->uri_for("/grouping_2d/$dataset->{'gx'}/$dataset->{'gy'}/")
			);
			$c->detach();
		}
		( $geneA, $geneB ) =
		  $self->check_local( $c, $geneA, $geneB, $dataset->{'gx'},
			$dataset->{'gy'} );

		$dataset->{'gg'}->read_grouping( $path . "Grouping.$geneA.$geneB" )
		  if ( -f $path . "Grouping.$geneA.$geneB" );

		
		if (   $c->form->submitted() eq "Submit"
			|| $c->form->submitted() eq 'Analyze using this grooping' )
		{
			$self->config_file( $c, 'grouping2D.txt', $dataset );
			unless ( defined $dataset->{'x1'} ) {
				unless (
					$c->form->submitted() eq 'Analyze using this grooping' )
				{
					$c->res->redirect(
						$c->uri_for(
							"/grouping_2d/$dataset->{'gx'}/$dataset->{'gy'}/")
					);
					$c->detach();
				}

			}
			else {
				my ( $xaxis, $yaxis ) =
				  $data->axies( $geneA, $geneB , GD::Image->new(10,10) );
				if ( $dataset->{'x1'} =~ m/\d+/ ) {
					foreach ( 'x1', 'x2' ) {
						$dataset->{$_} = $xaxis->pix2value( $dataset->{$_} );
					}
					foreach ( 'y1', 'y2' ) {
						$dataset->{$_} = $yaxis->pix2value( $dataset->{$_} );
					}
					$dataset->{'groupname'} = "Grouping.$geneA.$geneB";
					##Store the group!
					$dataset->{'gg'}->AddGroup( $geneA, $geneB, map { $dataset->{$_} } 'x1',
						'x2', 'y2', 'y1' );
					
					$dataset->{'gg'}->write_grouping ( join("/",$path,"Grouping.$geneA.$geneB" ));
					
					my $script = $c->model('RScript')-> create_script($c,'geneGroup2D',$dataset);
					$c->model('RScript')->runScript( $c, $c->session_path(), "$dataset->{'groupname'}.R", $script, 1 );
					
					
					$c->model('scrapbook')->init( $c->scrapbook() )
					  ->Add(
"<h3>Create Grouing based on two genes</h3>\n<i>options:"
						  . $self->options_to_HTML_table($dataset)
						  . "</i>\n" );
				}
			}
			## translate between position and value!
		}
		elsif ( $c->form->submitted() eq "Clear all groups" ) {
			$c->model('GeneGroups')->clear();
			foreach ( 'x1', 'x2', 'y1', 'y2' ) {
				$dataset->{$_} = '';
			}
			system( "rm -Rf " . $self->path($c) );
			system( "rm -f " . $c->session_path() . "Grouping.*.*.png" );
			$self->config_file( $c, 'grouping2D.txt', $dataset );
			$c->model('scrapbook')->init( $c->scrapbook() )
			  ->Add(
				    "<h3>Drop all Grouings based on two genes</h3>\n<i>options:"
				  . $self->options_to_HTML_table($dataset)
				  . "</i>\n" );
			$c->res->redirect( $c->uri_for("/grouping_2d/$geneA/$geneB/") );
			$c->detach();
		}
		if ( $c->form->submitted() eq 'Analyze using this grouping' ) {
			$c->model('scrapbook')->init( $c->scrapbook() )
			  ->Add("The final 2D grouping for $geneA vs. $geneB" , $self->path($c) . "Grouping.$geneA.$geneB.png" );
			$c->res->redirect( $c->uri_for("/analyse/re_run/Grouping.$geneA.$geneB") );
			$c->detach();
		}

	}
	$gg = $c->model('GeneGroups');

#Carp::confess (  "\$exp = ".root->print_perl_var_def( {map { $_ => $gg->{$_} } keys %$gg } ).";\n" );
	if ( defined $geneB ) {
		$gg->read_grouping( $self->path($c) . "Grouping.$geneA.$geneB" )
		  if ( -f $self->path($c) . "Grouping.$geneA.$geneB" );
		$gg->read_old_grouping( $self->path($c)."../2D_data_color.xls" );
		Carp::confess ( "file not found: ".$self->path($c)."../2D_data_color.xls" ) unless ( -f $self->path($c)."../2D_data_color.xls" );
		$gg->{'data'} = $data;
		$gg->plot( $self->path($c) . "Grouping.$geneA.$geneB.png",
			$geneA, $geneB);
		if ( $gg->nGroup() == 0 ){
			$c->stash->{'warning'} = "The sample colors are taken from the last active grouping.";
		}
		$c->stash->{'data'} =
		  $c->uri_for(
			'/files/index/' . $self->path($c) . "Grouping.$geneA.$geneB.png" );
	}
	else {
		$c->stash->{'data'} =
		  '/static/images/No_selection.png';    ## this is served by apache!
	}

	#Carp::confess( $gg->AsString() );
	$c->form->type('TT2');

#$c->form->template({ type => 'TT2', 'template' => 'root/src/form/grouping_2d.tt2', variable => 'form' });
	$c->form->template(
		$c->config->{'root'}.'src'. '/form/grouping_2d.tt2' );
	$c->stash->{'template'} = 'grouping_2d.tt2';

}

sub check_local {
	my ( $self, $c, $OgA, $OgB, $NgA, $NgB ) = @_;
	$c->stash->{'message'} .= "Check $OgA, $OgB, $NgA, $NgB\n";
	unless ( defined $OgB ) {
		$self->{'info'} = 'NEW';
		return ( $NgA, $NgB );
	}
	if ( !( ( $OgA eq $NgA ) && ( $OgB eq $NgB ) ) ) {
		$c->model('GeneGroups')->init();

		#Carp::confess ( $c->model('GeneGroups')-> AsString() );
	}
	return ( $NgA, $NgB );
}

sub path {
	my ( $self, $c ) = @_;
	Carp::confess("I need a HTpcrA object at startup!\n")
	  unless ( defined $c );
	mkdir( $c->session_path() . '2d_groups/' )
	  unless ( -d $c->session_path() . '2d_groups/' );
	return $c->session_path() . '2d_groups/';
}

sub Javascript {
	my ( $self, $c ) = @_;
	return $self->Script($c,
'<link rel="stylesheet" type="text/css" href="/css/imgareaselect-default.css" />'
	  . "\n"
	  . '<script type="text/javascript" src="/scripts/jquery.min.js"></script>'
	  . "\n"
	  . '<script type="text/javascript" src="/scripts/jquery.imgareaselect.pack.js"></script>'
	  . "\n"
	  . '<script type="text/javascript" src="/scripts/grouping2d.js"></script>'
	  . "\n" );
}

=head1 AUTHOR

Stefan Lang

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
