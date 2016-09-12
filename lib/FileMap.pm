# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Copyright (c) 2015,2016 by Delphix. All rights reserved.
#
# Program Name : FileMap.pm
# Description  : File Map validation
# Author       : Marcin Przepiorowski
# Created      : 13 Apr 2015 (v2.0.0)
#
#


package FileMap;

use warnings;
use strict;
use Data::Dumper;
use JSON;
use Toolkit_helpers qw (logger);

# constructor
# parameters 
# - dlpxObject - connection to DE
# - debug - debug flag (debug on if defined)

sub new {
    my $classname  = shift;
    my $dlpxObject = shift;
    my $debug = shift;
    logger($debug, "Entering FileMap::constructor",1);
    
    my %hosts;
    my $self = {
        _hosts => \%hosts,
        _dlpxObject => $dlpxObject,
        _debug => $debug
    };
    
    bless($self,$classname);
    
    return $self;
}

# Procedure setMapFile
# parameters: 
# - mapfile - hash with map file
# Set a map file rules for object

sub setMapFile {
    my $self = shift;
    my $mapfile = shift;
    
    logger($self->{_debug}, "Entering FileMap::setMapFile",1);  

    $self->{_mapping_rule_hash} = $mapfile;

    my $mapping_rule_de = '';

    while ( my ($key,$value) = each %{$mapfile} ) {
        if ($mapping_rule_de eq '') {
            $mapping_rule_de = $key . ":" . $value;
        } else {
            $mapping_rule_de = $mapping_rule_de . "\n" . $key . ":" . $value;      
        }
    }

    $self->{_mapping_rule} = $mapping_rule_de;

}

# Procedure loadMapFile
# parameters: 
# - file - name of files with rules (format orig:replace, each rule in separated line)
# Set a map file rules for object

sub loadMapFile {
    my $self = shift;
    my $file = shift;
    my %map_hash;

    logger($self->{_debug}, "Entering FileMap::loadMapFile",1);  

    open (my $FD, $file) or die ("Can't open file $file : $!");

    while(my $line = <$FD>) {
        chomp $line;
        if ($line =~ m/^#/ ) {
            next;
        }
        my @line_split = split (":",$line);

        if (! defined($line_split[0])) {
            die ("Line $line in file $file has an error. Check if there is colon sign. Can't continue");
        }

        if (! defined($line_split[1])) {
            $line_split[1] = '';
        }

        $map_hash{$line_split[0]} = $line_split[1];
        
    }

    close $FD;

    $self->setMapFile(\%map_hash);

}


# Procedure setSource
# parameters: 
# - source - name of source db
# Set a reference for a source db

sub setSource {
    my $self = shift;
    my $source = shift;
    
    logger($self->{_debug}, "Entering FileMap::setSource",1);  

    my $sources = new Source_obj($self->{_dlpxObject}, $self->{_debug});
    my $sourceitem = $sources->getSourceByName($source);

    $self->{_source_ref} = $sourceitem->{container};
}

# Procedure validate
# parameters: none
# Validate a mapping rules
# Return 0 if OK, 1 if failure

sub validate {
    my $self = shift;
    my %fileMapping_request;
    logger($self->{_debug}, "Entering FileMap::validate",1);  

    $fileMapping_request{"type"} = "FileMappingParameters";
    $fileMapping_request{"mappingRules"} = $self->{_mapping_rule};
    $fileMapping_request{"timeflowPointParameters"}{"type"} = "TimeflowPointSemantic";
    $fileMapping_request{"timeflowPointParameters"}{"container"} = $self->{_source_ref};

    my $json_data = to_json(\%fileMapping_request);

    my $operation = 'resources/json/delphix/database/fileMapping';

    my ($result, $result_fmt) = $self->{_dlpxObject}->postJSONData($operation, $json_data);

    if ($result->{status} eq 'OK') {
        my $mapped_files = $result->{result}->{mappedFiles};
        $self->{mappedFiles} = $mapped_files;
        return 0;
    } else {
        return 1;
    }

}

# Procedure GetMapping_rule
# parameters: none
# Return mapping rule

sub GetMapping_rule {
    my $self = shift;
    logger($self->{_debug}, "Entering FileMap::GetMapping_rule",1);  
    return $self->{_mapping_rule};
}

# Procedure GetMappedFiles
# parameters: none
# Return mapped files result

sub GetMappedFiles {
    my $self = shift;
    logger($self->{_debug}, "Entering FileMap::GetMappedFiles",1);  
    return $self->{mappedFiles};
}

1;