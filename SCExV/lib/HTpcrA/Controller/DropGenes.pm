package HTpcrA::Controller::DropGenes;
use stefans_libs::flexible_data_structures::data_table;
use HTpcrA::EnableFiles;
use Moose;
use namespace::autoclean;

with 'HTpcrA::EnableFiles';

#BEGIN { extends 'HTpcrA::base_db_controler';};
BEGIN { extends 'Catalyst::Controller'; }
use Digest::MD5 qw(md5_hex);

=head1 NAME

HTpcrA::Controller::analyse - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index : Path : Form {
	my ( $self, $c, @args ) = @_;
	#my $hash = $self->config_file( $c, 'dropping_samples.txt' );
	my $path = $self->check($c);
	
	$self->slurp_Heatmaps( $c, $path );
	
	if ( -f "$path/webGL/index.html" ) {
		$self->{'webGL'} = "$path/webGL/index.html";
		$self->slurp_webGL( $c, $self->{'webGL'}, $path );
	}

	## now the form to remove the samples
	$self->{'form_array'} = [];

	$self->Select_Options( $c, $path."/preprocess" );

	push(
		@{ $self->{'form_array'} },
		{
			'comment'  => 'Gene Selection',
			'name'     => 'Genes',
			'value'    => '',
			'options'  => $self->{'select_options'},   ## any sample in the data
			'required' => 0,
			'multiple' => 1,
			'size' => 17,
		}
	);
	$self->Javascript($c);
	foreach ( @{ $self->{'form_array'} } ) {
		$c->form->field( %{$_} );
	}
	if ( $c->form->submitted && $c->form->validate ) {
		## exclude some samples!!
		$self->R_remove_genes( $c, $self->__process_returned_form($c) );
	}

	$c->form->template( $c->config->{'root'}.'src'. '/form/dropgenes.tt2' );
	$c->stash->{'template'} = 'DropGenes.tt2';
}

sub R_remove_genes {
	my ( $self, $c, $hash ) = @_;
	my $path = $c->session_path();
	$hash->{'path'} = $path;
	my $script = $c->model('RScript')->create_script($c, 'remove_genes', $hash );
	$c->model('RScript')->runScript( $c, $path, 'DropGenes.R', $script, 1 );

	$c->model('scrapbook')->init( $c->scrapbook() )
	  ->Add("<h3>Drop Genes</h3>\n<i>options:"
		  . $self->options_to_HTML_table($hash)
		  . "</i>\n" );
	$c->res->redirect( $c->uri_for("/analyse/re_run/") );
	$c->detach();
	return 1;
}

sub Select_Options {
	my ( $self, $c, $path ) = @_;
	
	opendir ( DIR, $path ) or Carp::confess ( $!. "\n$path") ;
	my @genes = sort map {my $g = $_ ; $g =~ s/.png$//; $g} grep ( !/_Heatmap/ , grep ( /png$/ ,readdir(DIR) )) ;

	$self->{'select_options'} = [
		map {
			{  $_ => $_ }
		} @genes
	];
	closedir(DIR);
	return $self->{'select_options'};
}

sub Javascript {
	my ( $self, $c ) = @_;
	return $self->Script( $c, '<script type="text/javascript" src="'.$c->uri_for('/scripts/figures.js').'"></script>');
}
1;
